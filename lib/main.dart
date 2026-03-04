import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';

import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'core/bindings/initial_binding.dart';
import 'core/translations/app_translations.dart';
import 'core/utils/debug_logger.dart';
import 'core/services/auth_service.dart';
import 'modules/home/controllers/home_controller.dart';
import 'services/global_settings_service.dart';
import 'core/services/supabase_rest_client.dart';
import 'core/services/realtime_service.dart';
import 'core/services/update_service.dart';
import 'core/widgets/update_dialog.dart';

void main() async {
  logDebug('App Started');

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      logDebug('WidgetsFlutterBinding Initialized');

      // Route Flutter errors to our zone handler so we can see them
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        logDebug('FlutterError: ${details.exception}\n${details.stack}');
      };

      // Env vars now passed via --dart-define (compile-time)
      logDebug('Using compile-time environment config');

      // Initialize GetStorage
      await GetStorage.init();
      logDebug('GetStorage Initialized');

      // Initialize sqflite_ffi for Windows/Linux/macOS
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // NOTE: With sqflite_sqlcipher, we don't use databaseFactoryFfi directly
        // if it's initialized differently. sqflite_sqlcipher has its own
        // FFI setup or relies on sqlite3_flutter_libs.
        sqfliteFfiInit();
        // Use the FFI database factory
        databaseFactory = databaseFactoryFfi;
        logDebug('SQFlite FFI Initialized for SQLCipher');

        // Initialize window_manager to prevent layout overflow
        await windowManager.ensureInitialized();

        WindowOptions windowOptions = const WindowOptions(
          size: Size(1280, 720),
          minimumSize: Size(400, 600),
          center: true,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.normal,
        );

        windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });

        logDebug('WindowManager Initialized with min size 1024x600');
      }

      // Initialize date formatting for Vietnamese
      await initializeDateFormatting('vi', null);
      logDebug('Date Formatting Initialized');

      // Initialize Core Services
      // Note: Services are now initialized via InitialBinding -> SplashController
      // This allows the UI to show a loading screen instead of a white screen.

      logDebug('All initialization complete, running app...');

      runApp(const OkadaVetClinicApp());

      // Check for updates after app is fully loaded (non-blocking)
      Future.delayed(const Duration(seconds: 3), () {
        if (Platform.isWindows && Get.isRegistered<UpdateService>()) {
          UpdateService.to.checkForUpdate().then((hasUpdate) {
            if (hasUpdate) {
              UpdateDialog.show();
            }
          });
        }
      });
    },
    (error, stack) {
      debugPrint('Uncaught error: $error');
      logDebug('Uncaught Error: $error');
    },
  );
}

class OkadaVetClinicApp extends StatelessWidget {
  const OkadaVetClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'PetClinic',
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      defaultTransition: Transition.fadeIn,
      getPages: AppPages.routes,
      initialRoute: AppPages.initial,
      locale: const Locale('vi', 'VN'),
      fallbackLocale: const Locale('en', 'US'),
      translations: AppTranslations(),
      routingCallback: (routing) {
        if (routing?.current == Routes.home &&
            Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().loadDashboardData();
        }
      },
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();

        final data = MediaQuery.of(context);
        // Increase text scale by 15% on mobile devices (< 600px)
        if (data.size.width < 600) {
          return MediaQuery(
            data: data.copyWith(textScaler: const TextScaler.linear(1.15)),
            child: child,
          );
        }
        return child;
      },
    );
  }
}
