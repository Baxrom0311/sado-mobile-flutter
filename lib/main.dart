import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import 'core/cache.dart';
import 'core/messenger.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'data/local/preferences.dart';
import 'providers/providers.dart';
import 'widgets/offline_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await OfflineCache.init();
  final prefs = await Preferences.open();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
      ],
      child: const SadoApp(),
    ),
  );
}

class SadoApp extends ConsumerWidget {
  const SadoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    // Whenever the device transitions back from offline → online, try to
    // upload any queued assessment audio. Best-effort; the chip in the UI
    // also lets the user trigger the same flow manually.
    //
    // We surface a snackbar via the global messenger key so the user gets
    // a confirmation that their offline recordings made it to the server,
    // regardless of which screen they happen to be on. Localisations are
    // resolved up-front from the active locale so we don't have to pull
    // them through a `BuildContext` after an `await` (analyzer hates that
    // and the messenger's context outlives the listener anyway).
    ref.listen<AsyncValue<bool>>(isOfflineProvider, (prev, next) async {
      final wasOffline = prev?.asData?.value == true;
      final nowOnline = next.asData?.value == false;
      if (!wasOffline || !nowOnline) return;
      final l = lookupL(locale);
      final result = await flushPendingUploads(ref);
      if (result.succeeded == 0) return;
      showAppSnackBar(
        SnackBar(content: Text(l.uploadsSyncedAuto(result.succeeded))),
      );
    });

    return MaterialApp.router(
      title: 'SADO',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      routerConfig: router,
    );
  }
}
