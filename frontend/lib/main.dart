import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/injection.dart';
import 'core/i18n/i18n.dart';
import 'core/offline/field_encryptor.dart';
import 'core/offline/local_database.dart';
import 'core/offline/sync_manager.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  // SharedPreferences backs both the saved language and the i18n cache; it is
  // cross-platform (incl. web) so it's safe to initialize everywhere.
  final prefs = await SharedPreferences.getInstance();

  // Offline storage bootstrap is BEST-EFFORT — a failure must never block boot.
  // Mobile/desktop get full offline support; web degrades to online-only.
  try {
    await FieldEncryptor.instance.init();
    if (!kIsWeb) {
      await LocalDatabase.instance.db;
      await LocalDatabase.instance.cleanExpiredNormalized();
    }
  } catch (e, st) {
    debugPrint('Offline storage init failed (continuing online-only): $e\n$st');
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const ErpApp(),
    ),
  );
}

class ErpApp extends ConsumerWidget {
  const ErpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final i18n = ref.watch(i18nControllerProvider);
    ref.watch(syncManagerProvider); // boot eagerly

    return ScreenUtilInit(
      designSize: const Size(1440, 900),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Shamel ERP',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          routerConfig: router,
          locale: i18n.locale.locale,
          supportedLocales: AppLocale.values.map((l) => l.locale),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Expose translations to the entire navigator subtree.
          builder: (context, navigator) => TranslationsScope(
            state: i18n,
            child: navigator ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
