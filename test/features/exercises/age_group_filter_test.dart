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

Exercise _exercise({
  required String id,
  required String title,
  required String ageGroup,
  String category = 'articulation',
}) {
  return Exercise(
    id: id,
    title: title,
    description: 'desc-$id',
    category: category,
    ageGroup: ageGroup,
    difficulty: 'easy',
    language: 'uz',
    durationMinutes: 5,
    isActive: true,
  );
}

/// HTTP adapter that always errors out — keeps the in-memory fake notifier
/// from accidentally hitting the network during widget tests.
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

/// In-memory fake of [PaginatedExercisesNotifier] that filters the seeded
/// dataset by ageGroup (and category, for the "all ages" round-trip
/// assertion). Extending the real type lets us pass it straight to
/// `paginatedExercisesProvider.overrideWith`.
class _FakeExercisesNotifier extends PaginatedExercisesNotifier {
  _FakeExercisesNotifier(this._all) : super(_unusedApi()) {
    state = PaginatedExercisesState(
      items: _all,
      isLoading: false,
      hasMore: false,
    );
  }

  static ExercisesApi _unusedApi() {
    final dio = Dio()..httpClientAdapter = _NeverAdapter();
    return ExercisesApi(dio);
  }

  final List<Exercise> _all;

  void _apply({String? category, String? ageGroup}) {
    final filtered = _all.where((e) {
      if (category != null && e.category != category) return false;
      if (ageGroup != null && e.ageGroup != ageGroup) return false;
      return true;
    }).toList();
    state = PaginatedExercisesState(
      items: filtered,
      isLoading: false,
      hasMore: false,
      category: category,
      ageGroup: ageGroup,
    );
  }

  @override
  Future<void> refresh() async =>
      _apply(category: state.category, ageGroup: state.ageGroup);

  @override
  Future<void> setCategory(String? category) async {
    if (category == state.category) return;
    _apply(category: category, ageGroup: state.ageGroup);
  }

  @override
  Future<void> setAgeGroup(String? ageGroup) async {
    if (ageGroup == state.ageGroup) return;
    _apply(category: state.category, ageGroup: ageGroup);
  }

  @override
  Future<void> loadMore() async {/* no pages in tests */}
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

Widget _wrap(List<Exercise> items) {
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
      locale: const Locale('uz'),
      routerConfig: _router(),
    ),
  );
}

void main() {
  testWidgets('renders the age-group filter row with localized labels',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _exercise(id: '1', title: 'A', ageGroup: '3-4'),
      _exercise(id: '2', title: 'B', ageGroup: '5-6'),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Yosh bo\'yicha'), findsOneWidget);
    expect(find.text('Barcha yoshlar'), findsOneWidget);
    expect(find.text('2-3 yosh'), findsOneWidget);
    expect(find.text('3-4 yosh'), findsOneWidget);
    expect(find.text('5-6 yosh'), findsOneWidget);
  });

  testWidgets('selecting "5-6 yosh" hides exercises in other age groups',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _exercise(id: '1', title: 'Toddler talk', ageGroup: '3-4'),
      _exercise(id: '2', title: 'Big kid talk', ageGroup: '5-6'),
      _exercise(id: '3', title: 'Pre-school talk', ageGroup: '4-5'),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('5-6 yosh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Big kid talk'), findsOneWidget);
    expect(find.text('Toddler talk'), findsNothing);
    expect(find.text('Pre-school talk'), findsNothing);
  });

  testWidgets('switching back to "Barcha yoshlar" restores all items',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _exercise(id: '1', title: 'Toddler talk', ageGroup: '3-4'),
      _exercise(id: '2', title: 'Big kid talk', ageGroup: '5-6'),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('5-6 yosh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Toddler talk'), findsNothing);

    await tester.tap(find.text('Barcha yoshlar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Toddler talk'), findsOneWidget);
    expect(find.text('Big kid talk'), findsOneWidget);
  });

  testWidgets('age-group + category filters compose (5-6 + breathing)',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _exercise(
          id: '1', title: 'A', ageGroup: '5-6', category: 'articulation'),
      _exercise(
          id: '2', title: 'B', ageGroup: '5-6', category: 'breathing'),
      _exercise(
          id: '3', title: 'C', ageGroup: '3-4', category: 'breathing'),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('5-6 yosh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Nafas olish').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing); // wrong category
    expect(find.text('C'), findsNothing); // wrong age
  });
}
