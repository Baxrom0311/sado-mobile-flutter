import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sado_mobile/core/cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sado_offline_cache_test_');
    // Hive.init takes a directory path — this is enough for openBox to work
    // in pure-Dart tests without needing path_provider.
    Hive.init(tempDir.path);
    OfflineCache.debugResetForTesting();
  });

  tearDown(() async {
    OfflineCache.debugResetForTesting();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('OfflineCache', () {
    test('round-trips a list of maps via JSON encoding', () async {
      final payload = [
        {'id': 'c-1', 'name': 'Aziz'},
        {'id': 'c-2', 'name': 'Diyora'},
      ];

      await OfflineCache.save('children', payload);
      final read = OfflineCache.read('children');

      expect(read, isA<List>());
      expect(read, hasLength(2));
      expect(read.first['id'], 'c-1');
      expect(read.last['name'], 'Diyora');
    });

    test('returns null when the key has never been saved', () async {
      // Force init even though we never wrote — read() must not throw.
      await OfflineCache.save('seed', 'noop');
      expect(OfflineCache.read('missing-key'), isNull);
    });

    test('overwrites a previous value at the same key', () async {
      await OfflineCache.save('exercises', ['old']);
      await OfflineCache.save('exercises', ['new', 'newer']);

      final read = OfflineCache.read('exercises');
      expect(read, ['new', 'newer']);
    });

    test('clear() drops every cached entry', () async {
      await OfflineCache.save('a', [1]);
      await OfflineCache.save('b', [2]);

      await OfflineCache.clear();

      expect(OfflineCache.read('a'), isNull);
      expect(OfflineCache.read('b'), isNull);
    });

    test('read returns null when the box has not been opened yet', () {
      // Force the cache into pristine state without calling save() —
      // read() must short-circuit to null instead of throwing.
      OfflineCache.debugResetForTesting();
      expect(OfflineCache.read('any-key'), isNull);
    });
  });
}
