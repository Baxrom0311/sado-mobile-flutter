import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/api/exercises_api.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/features/exercises/exercises_list_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/paginated_exercises_provider.dart';

/// HTTP adapter that always errors out — guarantees the fake notifier never
/// hits the network even if [PaginatedExercisesNotifier]'s constructor body
/// fires its initial refresh before our override has a chance to take over.
class _NeverAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      Future<ResponseBody>.error(StateError('test: no network'));

  @override
  void close({bool force = false}) {}
}

/// Same fake notifier shape as the category-filter tests, but it preserves
/// the search query passed in so the filtered-items getter exercises the
/// real client-side search code path.
class _FakeExercisesNotifier extends PaginatedExercisesNotifier {
  _FakeExercisesNotifier(List<Exercise> all) : super(_unusedApi()) {
    state = PaginatedExercisesState(
      items: all,
      isLoading: false,
      hasMore: false,
    );
  }

  static ExercisesApi _unusedApi() {
    final dio = Dio()..httpClientAdapter = _NeverAdapter();
    return ExercisesApi(dio);
  }

  @override
  Future<void> refresh() async {/* no-op */}

  @override
  Future<void> setCategory(String? category) async {/* no-op */}

  @override
  Future<void> loadMore() async {/* no-op */}
}

Exercise _exercise({
  required String id,
  required String title,
  required String description,
  String category = 'articulation',
}) {
  return Exercise(
    id: id,
    title: title,
    description: description,
    category: category,
    ageGroup: '5-6',
    difficulty: 'easy',
    language: 'uz',
    durationMinutes: 5,
    isActive: true,
  );
}

GoRouter _router() => GoRouter(
      initialLocation: '/exercises',
      routes: [
        GoRoute(
          path: '/exercises',
          builder: (_, __) => const ExercisesListScreen(),
        ),
        GoRoute(
          path: '/exercises/:id',
          builder: (_, state) =>
              Scaffold(body: Text('detail-${state.pathParameters['id']}')),
        ),
      ],
    );

Widget _wrap(List<Exercise> items, {Locale locale = const Locale('uz')}) {
  return ProviderScope(
    overrides: [
      paginatedExercisesProvider.overrideWith(
        (ref) => _FakeExercisesNotifier(items),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      locale: locale,
      routerConfig: _router(),
    ),
  );
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  group('PaginatedExercisesState search', () {
    final all = [
      _exercise(id: '1', title: 'R tovushi', description: 'Tilning uchi'),
      _exercise(
        id: '2',
        title: 'Nafas mashqi',
        description: 'Chuqur nafas oling',
      ),
      _exercise(
        id: '3',
        title: 'L tovushi',
        description: 'Til ko\'tariladi',
      ),
    ];

    test('empty query returns every item', () {
      final state = PaginatedExercisesState(items: all);
      expect(state.filteredItems, equals(all));
      expect(state.isSearching, isFalse);
    });

    test('whitespace-only query is treated as empty', () {
      final state =
          PaginatedExercisesState(items: all, searchQuery: '   ');
      expect(state.filteredItems, equals(all));
      expect(state.isSearching, isFalse);
    });

    test('matches on title, case-insensitively', () {
      final state =
          PaginatedExercisesState(items: all, searchQuery: 'NAFAS');
      expect(state.filteredItems.map((e) => e.id), equals(['2']));
      expect(state.isSearching, isTrue);
    });

    test('matches on description too', () {
      final state =
          PaginatedExercisesState(items: all, searchQuery: 'tilning');
      expect(state.filteredItems.map((e) => e.id), equals(['1']));
    });

    test('returns empty list when nothing matches', () {
      final state =
          PaginatedExercisesState(items: all, searchQuery: 'xxxxx');
      expect(state.filteredItems, isEmpty);
      expect(state.isSearching, isTrue);
    });
  });

  group('Exercises search field UI', () {
    testWidgets('renders the search field with the localized hint',
        (tester) async {
      await tester.pumpWidget(_wrap([
        _exercise(id: '1', title: 'R tovushi', description: 'desc'),
      ]));
      await _settle(tester);

      expect(find.text('Mashqni qidirish'), findsOneWidget);
      // Material's TextField expands the prefix mic of the field too —
      // we just need to know the widget is in the tree.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('typing filters the list to matching titles',
        (tester) async {
      await tester.pumpWidget(_wrap([
        _exercise(id: '1', title: 'R tovushi', description: 'desc-1'),
        _exercise(id: '2', title: 'Nafas mashqi', description: 'desc-2'),
        _exercise(id: '3', title: 'L tovushi', description: 'desc-3'),
      ]));
      await _settle(tester);

      expect(find.text('R tovushi'), findsOneWidget);
      expect(find.text('Nafas mashqi'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nafas');
      await _settle(tester);

      expect(find.text('Nafas mashqi'), findsOneWidget);
      expect(find.text('R tovushi'), findsNothing);
      expect(find.text('L tovushi'), findsNothing);
    });

    testWidgets('non-matching query renders the no-results empty state',
        (tester) async {
      await tester.pumpWidget(_wrap([
        _exercise(id: '1', title: 'R tovushi', description: 'desc-1'),
      ]));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'qwertyqwerty');
      await _settle(tester);

      // Localized empty-state copy specific to a *search* miss (not the
      // generic "no exercises in this category" message).
      expect(find.text('Hech narsa topilmadi'), findsOneWidget);
      expect(
        find.text('Boshqa kalit so\'z bilan urinib ko\'ring'),
        findsOneWidget,
      );
    });

    testWidgets('the inline clear button restores the full list',
        (tester) async {
      await tester.pumpWidget(_wrap([
        _exercise(id: '1', title: 'R tovushi', description: 'desc-1'),
        _exercise(id: '2', title: 'Nafas mashqi', description: 'desc-2'),
      ]));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'nafas');
      await _settle(tester);
      expect(find.text('R tovushi'), findsNothing);

      // The suffix close icon is only present once the field is non-empty.
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await _settle(tester);

      expect(find.text('R tovushi'), findsOneWidget);
      expect(find.text('Nafas mashqi'), findsOneWidget);
    });

    testWidgets('renders the localized hint in Russian', (tester) async {
      await tester.pumpWidget(_wrap(
        [_exercise(id: '1', title: 'Звук Р', description: 'desc')],
        locale: const Locale('ru'),
      ));
      await _settle(tester);

      expect(find.text('Поиск упражнения'), findsOneWidget);
    });
  });
}
