import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sado_mobile/core/cache.dart';
import 'package:sado_mobile/data/api/exercises_api.dart';
import 'package:sado_mobile/providers/paginated_exercises_provider.dart';

/// Lightweight in-memory transport that stubs the GET /exercises endpoint
/// with cursor-paginated pages. We avoid mocktail so the test stays
/// dependency-light.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.pages);

  /// Each entry is one page payload keyed by the `cursor` query value
  /// (null for the first request).
  final Map<String?, Map<String, dynamic>> pages;

  int callCount = 0;

  /// Snapshot of the most recent request's queryParameters so tests can
  /// assert the notifier forwards filter tokens (`category`,
  /// `age_group`, `difficulty`, …) onto the wire correctly.
  Map<String, dynamic>? lastQuery;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    lastQuery = Map<String, dynamic>.from(options.queryParameters);
    final cursor = options.queryParameters['cursor'] as String?;
    final body = pages[cursor];
    if (body == null) {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'unknown cursor'}),
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _ex(String id, String category) => {
      'id': id,
      'title': 'Exercise $id',
      'description': 'desc-$id',
      'category': category,
      'age_group': '5-6',
      'difficulty': 'easy',
      'language': 'uz',
      'duration_minutes': 5,
      'is_active': true,
    };

({ExercisesApi api, _StubAdapter adapter}) _api(
    Map<String?, Map<String, dynamic>> pages) {
  final adapter = _StubAdapter(pages);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
    ..httpClientAdapter = adapter;
  return (api: ExercisesApi(dio), adapter: adapter);
}

void main() {
  late Directory tempDir;
  final notifiers = <PaginatedExercisesNotifier>[];

  PaginatedExercisesNotifier track(PaginatedExercisesNotifier n) {
    notifiers.add(n);
    return n;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sado_paginated_test');
    OfflineCache.debugResetForTesting();
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    for (final n in notifiers) {
      n.dispose();
    }
    notifiers.clear();
    OfflineCache.debugResetForTesting();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('PaginatedExercisesNotifier', () {
    test('loads the first page on construction', () async {
      final t = _api({
        null: {
          'items': [_ex('1', 'articulation'), _ex('2', 'breathing')],
          'next_cursor': 'cur-2',
          'has_more': true,
        },
      });

      final notifier = track(PaginatedExercisesNotifier(t.api));
      await notifier.ready;

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.items.map((e) => e.id).toList(), ['1', '2']);
      expect(notifier.state.hasMore, isTrue);
      expect(notifier.state.nextCursor, 'cur-2');
      expect(notifier.state.error, isNull);
      expect(t.adapter.callCount, 1);
    });

    test('loadMore appends the second page and clears hasMore at the end',
        () async {
      final t = _api({
        null: {
          'items': [_ex('1', 'articulation')],
          'next_cursor': 'cur-2',
          'has_more': true,
        },
        'cur-2': {
          'items': [_ex('2', 'breathing'), _ex('3', 'fluency')],
          'next_cursor': null,
          'has_more': false,
        },
      });

      final notifier = track(PaginatedExercisesNotifier(t.api));
      await notifier.ready;
      expect(notifier.state.items.length, 1);

      await notifier.loadMore();

      expect(notifier.state.items.map((e) => e.id).toList(),
          ['1', '2', '3']);
      expect(notifier.state.hasMore, isFalse);
      expect(notifier.state.nextCursor, isNull);
      expect(notifier.state.isLoadingMore, isFalse);
      expect(t.adapter.callCount, 2);
    });

    test('loadMore is a no-op when hasMore is false', () async {
      final t = _api({
        null: {
          'items': [_ex('1', 'articulation')],
          'next_cursor': null,
          'has_more': false,
        },
      });

      final notifier = track(PaginatedExercisesNotifier(t.api));
      await notifier.ready;

      // No more pages — calling loadMore() must not issue another request.
      await notifier.loadMore();

      expect(notifier.state.items.length, 1);
      expect(notifier.state.hasMore, isFalse);
      expect(t.adapter.callCount, 1);
    });

    test('setCategory resets items and refetches', () async {
      final t = _api({
        null: {
          'items': const [],
          'next_cursor': null,
          'has_more': false,
        },
      });

      final notifier = track(PaginatedExercisesNotifier(t.api));
      await notifier.ready;
      final initialCalls = t.adapter.callCount;

      await notifier.setCategory('breathing');

      expect(notifier.state.category, 'breathing');
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.hasMore, isFalse);
      expect(t.adapter.callCount, initialCalls + 1);
    });

    test('setCategory to the same value does not refetch', () async {
      final t = _api({
        null: {
          'items': const [],
          'next_cursor': null,
          'has_more': false,
        },
      });

      final notifier = track(PaginatedExercisesNotifier(t.api));
      await notifier.ready;
      final initialCalls = t.adapter.callCount;

      await notifier.setCategory(null); // same as default

      expect(t.adapter.callCount, initialCalls);
    });

    test('setDifficulty switches state, refetches and forwards the filter '
        'on the wire', () async {
      final t = _api({
        null: {
          'items': const [],
          'next_cursor': null,
          'has_more': false,
        },
      });

      final notifier = track(PaginatedExercisesNotifier(t.api));
      await notifier.ready;
      final initialCalls = t.adapter.callCount;

      await notifier.setDifficulty('hard');

      expect(notifier.state.difficulty, 'hard');
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.hasMore, isFalse);
      expect(t.adapter.callCount, initialCalls + 1);
      // The stub captures every request — the most recent one must carry
      // the API-canonical token so the backend scopes the catalogue.
      expect(t.adapter.lastQuery?['difficulty'], 'hard');
    });

    test('setDifficulty to the same value is a no-op', () async {
      final t = _api({
        null: {
          'items': const [],
          'next_cursor': null,
          'has_more': false,
        },
      });

      final notifier = track(PaginatedExercisesNotifier(t.api));
      await notifier.ready;
      final initialCalls = t.adapter.callCount;

      await notifier.setDifficulty(null); // same as default
      expect(t.adapter.callCount, initialCalls);
    });

    test('setDifficulty(null) clears the filter from the wire', () async {
      final t = _api({
        null: {
          'items': const [],
          'next_cursor': null,
          'has_more': false,
        },
      });

      final notifier = track(PaginatedExercisesNotifier(t.api));
      await notifier.ready;
      await notifier.setDifficulty('easy');
      expect(t.adapter.lastQuery?['difficulty'], 'easy');

      await notifier.setDifficulty(null);

      expect(notifier.state.difficulty, isNull);
      // After clearing, the next request must not include `difficulty=null`
      // — otherwise the API would scope to a non-existent bucket and the
      // user would see an empty catalogue when toggling "All levels".
      expect(t.adapter.lastQuery?.containsKey('difficulty'), isFalse);
    });
  });
}
