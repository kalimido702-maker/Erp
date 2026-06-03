import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/di/injection.dart';
import 'core/offline/field_encryptor.dart';
import 'core/offline/local_database.dart';
import 'core/offline/sync_manager.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await configureDependencies();

  // Offline storage bootstrap is BEST-EFFORT. A failure here must never
  // prevent the app from booting (which would show a blank white screen).
  // - Mobile/desktop: full offline support (encryptor + SQLite).
  // - Web: sqflite has no web backend, so we skip the local DB and degrade
  //   to online-only instead of crashing before runApp().
  try {
    // Fix #4: Initialize AES encryptor before opening DB.
    // Key is generated on first run and stored in Keystore/Keychain (web: JS crypto).
    await FieldEncryptor.instance.init();

    if (!kIsWeb) {
      // Open local SQLite database (schema creation/migration runs here)
      await LocalDatabase.instance.db;

      // Fix #8: Clean expired normalized_entities on startup (bounded DB size)
      await LocalDatabase.instance.cleanExpiredNormalized();
    }
  } catch (e, st) {
    // Never block boot on storage init — log and continue online-only.
    debugPrint('Offline storage init failed (continuing online-only): $e\n$st');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      startLocale: const Locale('ar'),
      child: const ProviderScope(child: ErpApp()),
    ),
  );
}

class ErpApp extends ConsumerWidget {
  const ErpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(syncManagerProvider); // boot eagerly
    return ScreenUtilInit(
      designSize: const Size(1440, 900),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'ERP System',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          routerConfig: router,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
        );
      },
    );
  }
}
