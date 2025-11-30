import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'ui/screens/auth_gate.dart';
import 'ui/services/ui_service.dart';
import 'data/services/logger_service.dart';
import 'providers/theme_provider.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize logger service first
    final logger = LoggerService();
    await logger.initialize();
    await logger.info('App', 'Application starting...');

    // Load environment variables
    await dotenv.load(fileName: ".env");
    await logger.info('App', 'Environment variables loaded');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await logger.info('App', 'Firebase initialized');

    // Enable Firestore offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    await logger.info('App', 'Firestore offline persistence enabled');

    // Error handling - combine logger and Crashlytics
    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
      logger.error('Flutter', 'Flutter error caught', details.exception, details.stack);
    };

    runApp(const ProviderScope(child: OurArchiveApp()));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
    LoggerService().error('App', 'Uncaught error in runZonedGuarded', error, stack);
  });
}

class OurArchiveApp extends ConsumerWidget {
  const OurArchiveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lightTheme = ref.watch(lightThemeProvider);
    final darkTheme = ref.watch(darkThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'OurArchive',
      scaffoldMessengerKey: UiService.scaffoldMessengerKey,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
