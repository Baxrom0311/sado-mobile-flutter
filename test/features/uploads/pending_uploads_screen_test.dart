import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/core/theme.dart';
import 'package:sado_mobile/data/models/models.dart';
import 'package:sado_mobile/data/services/pending_uploads_service.dart';
import 'package:sado_mobile/features/uploads/pending_uploads_screen.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';
import 'package:sado_mobile/providers/providers.dart';
import 'package:sado_mobile/widgets/parrot_mascot.dart';

PendingUpload _job(
  String id, {
  String childId = 'c-1',
  String exerciseId = 'e-1',
  int retries = 0,
  DateTime? createdAt,
}) =>
    PendingUpload(
      id: id,
      childId: childId,
      exerciseId: exerciseId,
      audioPath: '/tmp/$id.m4a',
      createdAt: createdAt ?? DateTime(2024, 1, 1),
      retries: retries,
    );

Child _child(String id, String name) => Child(
      id: id,
      name: name,
      birthDate: DateTime(2019, 5, 1),
      gender: 'male',
      parentId: 'p-1',
      createdAt: DateTime(2024, 1, 1),
    );

Exercise _exercise(String id, String title, {String category = 'articulation'}) =>
    Exercise(
      id: id,
      title: title,
      description: 'desc',
      category: category,
      ageGroup: 'k1',
      difficulty: 'easy',
      language: 'uz',
      durationMinutes: 5,
      isActive: true,
    );

GoRouter _router() {
  return GoRouter(
    initialLocation: '/uploads',
    routes: [
      GoRoute(
        path: '/uploads',
        builder: (_, __) => const PendingUploadsScreen(),
      ),
      // The empty-state CTA navigates back to /, give it a real landing.
      GoRoute(
        path: '/',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('HOME_STUB'))),
      ),
    ],
  );
}

Widget _wrap({
  required List<PendingUpload> jobs,
  List<Child> children = const [],
  List<Exercise> exercises = const [],
}) {
  return ProviderScope(
    overrides: [
      pendingUploadsListProvider.overrideWith((ref) => Stream.value(jobs)),
      childrenProvider.overrideWith((ref) async => CachedResult(children)),
      exercisesProvider
          .overrideWith((ref) async => CachedResult(exercises)),
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
  // Realistic phone viewport so the header + list + bottom CTAs do not clip.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize =
        const Size(390 * 3, 844 * 3);
    binding.platformDispatcher.views.first.devicePixelRatio = 3.0;
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('PendingUploadsScreen', () {
    testWidgets(
      'empty queue renders the parrot, all-clear copy and a Home CTA',
      (tester) async {
        await tester.pumpWidget(_wrap(jobs: const []));
        await tester.pump(); // resolve providers
        await tester.pump(const Duration(milliseconds: 400)); // entrance

        // Friendly empty state, not a raw spinner / Material default.
        expect(find.byType(ParrotMascot), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Localized copy from app_uz.arb.
        expect(find.text('Hammasi yuborildi!'), findsOneWidget);
        // The home CTA is wired and reuses the existing 'home' key.
        expect(find.text('Bosh sahifa'), findsOneWidget);

        // Tap CTA → navigates to home stub.
        await tester.tap(find.text('Bosh sahifa'));
        await tester.pumpAndSettle();
        expect(find.text('HOME_STUB'), findsOneWidget);
      },
    );

    testWidgets(
      'with queued jobs joins each row with the resolved child + exercise',
      (tester) async {
        await tester.pumpWidget(_wrap(
          jobs: [
            _job('a', childId: 'c-1', exerciseId: 'e-1'),
            _job('b', childId: 'c-2', exerciseId: 'e-2', retries: 3),
          ],
          children: [
            _child('c-1', 'Aziza'),
            _child('c-2', 'Doniyor'),
          ],
          exercises: [
            _exercise('e-1', 'R harfi'),
            _exercise('e-2', 'Nafas mashqi'),
          ],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Both exercise titles surface…
        expect(find.text('R harfi'), findsOneWidget);
        expect(find.text('Nafas mashqi'), findsOneWidget);

        // …joined with the child name (uz label is "Bola").
        expect(find.text('Bola: Aziza'), findsOneWidget);
        expect(find.text('Bola: Doniyor'), findsOneWidget);

        // Header pluralization picks the "N yozuv navbatda" branch.
        expect(find.text('2 yozuv navbatda'), findsOneWidget);

        // Retry-count chip surfaces only when retries > 0.
        expect(find.text('Hali urinilmadi'), findsOneWidget); // job 'a'
        expect(find.text('3 marta urinildi'), findsOneWidget); // job 'b'

        // Per-row "retry now" buttons exist (one per job).
        expect(find.text('Hozir yuborish'), findsNWidgets(2));
      },
    );

    testWidgets(
      'unresolved child / exercise IDs degrade to localized fallback labels',
      (tester) async {
        await tester.pumpWidget(_wrap(
          jobs: [_job('z', childId: 'gone', exerciseId: 'gone')],
          children: const [],
          exercises: const [],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Fallbacks come straight from the .arb keys.
        expect(find.text('Mashq ma\'lumoti yo\'q'), findsOneWidget);
        expect(find.text('Bola: Bola ma\'lumoti yo\'q'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the discard icon opens a confirmation dialog with cancel + delete',
      (tester) async {
        await tester.pumpWidget(_wrap(
          jobs: [_job('a', childId: 'c-1', exerciseId: 'e-1')],
          children: [_child('c-1', 'Aziza')],
          exercises: [_exercise('e-1', 'R harfi')],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pumpAndSettle();

        // Confirmation copy from app_uz.arb.
        expect(find.text('Yozuvni o\'chirish'), findsOneWidget);
        expect(
          find.text(
              'Bu yozuvni o\'chirmoqchimisiz? Audio fayl ham qaytarib bo\'lmaydigan tarzda o\'chiriladi.'),
          findsOneWidget,
        );
        // Both actions render — keyed on the existing global 'cancel' / 'delete'.
        expect(find.text('Bekor qilish'), findsOneWidget);
        expect(find.text('O\'chirish'), findsOneWidget);

        // Cancelling the dialog leaves the job in place — no regression.
        await tester.tap(find.text('Bekor qilish'));
        await tester.pumpAndSettle();
        expect(find.text('R harfi'), findsOneWidget);
      },
    );
  });
}
