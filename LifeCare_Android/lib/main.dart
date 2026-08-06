// ignore: avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/router_for_platform.dart';
import 'core/services/offline_queue_service.dart';
import 'core/services/offline_database_service.dart';
import 'core/services/batch_sync_manager.dart';
import 'core/services/low_data_mode_service.dart';
import 'core/widgets/offline_indicator.dart';
import 'features/shared/data/services/user_activity_service.dart';
import 'core/providers/language_provider.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/fallback_material_localizations.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const _firestoreCacheSizeBytes = 100 * 1024 * 1024;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path URL strategy for proper deep linking on web
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  if (!kIsWeb) {
    try {
      await dotenv.load();
    } catch (e) {
      debugPrint('dotenv load skipped: $e');
    }
  }

  try {
    final isFirstFirebaseInitialization = Firebase.apps.isEmpty;
    if (isFirstFirebaseInitialization) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Firestore settings must be applied before the client is first used.
      // Reapplying them to an existing web client during hot restart can leave
      // the JavaScript SDK's active watch targets in an invalid state.
      if (kIsWeb && kReleaseMode) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: _firestoreCacheSizeBytes,
        );
      } else if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: _firestoreCacheSizeBytes,
        );
      } else {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
        );
      }
    }

    // Initialize offline queue service for operation retry. This is lightweight
    // and works on web/mobile because it uses SharedPreferences storage.
    await OfflineQueueService().initialize();

    if (!kIsWeb) {
      // Initialize offline database for local-first functionality
      await OfflineDatabaseService().database;

      // Initialize batch sync manager for efficient syncing
      await BatchSyncManager().initialize();
    }

    // Note: ConnectivityService initializes lazily when first accessed
    // This reduces startup time - it will auto-initialize when needed

    const enableFirebaseAppCheck = bool.fromEnvironment(
      'ENABLE_FIREBASE_APP_CHECK',
      defaultValue: false,
    );
    if (!kIsWeb && enableFirebaseAppCheck) {
      await FirebaseAppCheck.instance.activate(
        // ignore: deprecated_member_use
        androidProvider: AndroidProvider.playIntegrity,
        // ignore: deprecated_member_use
        appleProvider: AppleProvider.deviceCheck,
      );
    }

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await _initializeNotifications();
    }
  } catch (e) {
    debugPrint('Startup initialization failed: $e');
  }
  runApp(const LifeCareApp());
}

class LifeCareApp extends StatelessWidget {
  const LifeCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(
          create: (_) => LowDataModeService()..initialize(),
        ),
        if (!kIsWeb) ChangeNotifierProvider(create: (_) => BatchSyncManager()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return MaterialApp.router(
            title: AppConstants.appName,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: AppRouter.router,
            debugShowCheckedModeBanner: false,
            locale: languageProvider.locale,
            supportedLocales: const [
              Locale('en'), // English
              Locale('ha'), // Hausa
              Locale('sw'), // Swahili
              Locale('fr'), // French
              Locale('es'), // Spanish
              Locale('ig'), // Igbo
              Locale('yo'), // Yoruba
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              FallbackMaterialLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              FallbackCupertinoLocalizationsDelegate(),
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              // If the locale is Hausa, Swahili, or Fulfulde (not supported by Material/Cupertino),
              // use English for Material/Cupertino widgets but keep the locale for app translations
              if (locale != null) {
                final languageCode = locale.languageCode;
                // Check if the locale is supported by the app
                for (var supportedLocale in supportedLocales) {
                  if (supportedLocale.languageCode == languageCode) {
                    return supportedLocale;
                  }
                }
              }
              // Default to English if locale is not supported
              return const Locale('en');
            },
            builder: (context, child) {
              final routedApp = StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  // Initialize activity tracking when user state changes
                  if (snapshot.hasData && snapshot.data != null) {
                    UserActivityService().initializeActivityTracking();
                  }
                  return child ?? const SizedBox.shrink();
                },
              );

              return OfflineIndicator(child: routedApp);
            },
          );
        },
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}
