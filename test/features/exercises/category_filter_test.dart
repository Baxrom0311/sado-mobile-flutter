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
  required String category,
  String difficulty = 'easy',
  int duration = 5,
}) {
  return Exercise(
    id: id,
    title: title,
    description: 'desc-$id',
    category: category,
    ageGroup: '5-6',
    difficulty: difficulty,
    language: 'uz',
    durationMinutes: duration,
    isActive: true,
  );
}

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

/// Fake notifier that pretends to be a real [PaginatedExercisesNotifier]
/// but operates entirely on an in-memory dataset. We extend rather than
/// duplicate state shape so `paginatedExercisesProvider.overrideWith` is
/// satisfied at the type level.
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

  void _setFor(String? category) {
    final filtered = category == null
        ? _all
        : _all.where((e) => e.category == category).toList();
    state = PaginatedExercisesState(
      items: filtered,
      isLoading: false,
      hasMore: false,
      category: category,
    );
  }

  @override
  Future<void> refresh() async => _setFor(state.category);

  @override
  Future<void> setCategory(String? category) async {
    if (category == state.category) return;
    _setFor(category);
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
  // The exercises list ships three filter rows (category cards, age group
  // pills, difficulty pills) above the cards. Combined with shimmer
  // animations and the exercise cards themselves, the default 800×600
  // test viewport is too short to keep more than two cards in the
  // ListView's build window. Bumping the viewport for every test in this
  // file ensures `findsOneWidget` still holds for the third card without
  // resorting to scroll-into-view dances per assertion.
  setUp(() {
    final tester = TestWidgetsFlutterBinding.ensureInitialized();
    tester.platformDispatcher.views.first
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1.0;
  });

  tearDown(() {
    final tester = TestWidgetsFlutterBinding.ensureInitialized();
    tester.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('shows all exercises by default', (tester) async {
    await tester.pumpWidget(_wrap([
      _exercise(id: '1', title: 'R tovushi', category: 'articulation'),
      _exercise(id: '2', title: 'Nafas mashqi', category: 'breathing'),
      _exercise(id: '3', title: 'Lug\'at o\'yini', category: 'vocabulary'),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('R tovushi'), findsOneWidget);
    expect(find.text('Nafas mashqi'), findsOneWidget);
    expect(find.text('Lug\'at o\'yini'), findsOneWidget);
  });

  testWidgets('selecting "Nafas" hides non-breathing exercises',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _exercise(id: '1', title: 'R tovushi', category: 'articulation'),
      _exercise(id: '2', title: 'Nafas mashqi', category: 'breathing'),
      _exercise(id: '3', title: 'Lug\'at o\'yini', category: 'vocabulary'),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Nafas olish').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Nafas mashqi'), findsOneWidget);
    expect(find.text('R tovushi'), findsNothing);
    expect(find.text('Lug\'at o\'yini'), findsNothing);
  });

  testWidgets('switching back to "Barchasi" restores all items',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _exercise(id: '1', title: 'R tovushi', category: 'articulation'),
      _exercise(id: '2', title: 'Nafas mashqi', category: 'breathing'),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Nafas olish').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('R tovushi'), findsNothing);

    await tester.tap(find.text('Jami').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('R tovushi'), findsOneWidget);
    expect(find.text('Nafas mashqi'), findsOneWidget);
  });

  testWidgets('empty filtered result shows mascot empty state',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _exercise(id: '1', title: 'R tovushi', category: 'articulation'),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Lug\'at').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mashqlar topilmadi'), findsOneWidget);
  });

  testWidgets(
    'each exercise card hosts a Hero with a tag scoped to the exercise id '
    '— enables a smooth list → detail transition',
    (tester) async {
      await tester.pumpWidget(_wrap([
        _exercise(id: 'art-1', title: 'R tovushi', category: 'articulation'),
        _exercise(id: 'br-2', title: 'Nafas mashqi', category: 'breathing'),
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Each card must surface a Hero whose tag is unique per exercise so
      // multiple cards can coexist on screen without colliding.
      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == 'exercise-icon-art-1',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == 'exercise-icon-br-2',
        ),
        findsOneWidget,
      );
    },
  );
}
