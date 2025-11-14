import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'ui/screens/auth_gate.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables
    await dotenv.load(fileName: ".env");

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable Firestore offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Error handling
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    runApp(const ProviderScope(child: OurArchiveApp()));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
  });
}

class OurArchiveApp extends StatelessWidget {
  const OurArchiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OurArchive',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
