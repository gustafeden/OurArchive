# Suggested Commands for OurArchive

## Flutter Commands (ALWAYS use fvm)
- `fvm flutter pub get` - Install dependencies
- `fvm flutter run` - Run the app
- `fvm flutter build ios` - Build for iOS
- `fvm flutter build apk` - Build for Android
- `fvm flutter analyze` - Run static analysis
- `fvm flutter test` - Run tests (NEVER use `dart test`)
- `fvm flutter clean` - Clean build artifacts

## Development Workflow
- Use `fvm` prefix for ALL Flutter commands
- Tests must use `fvm flutter test` due to Flutter-specific dependencies

## Firebase
- Firebase configuration in `firebase/` directory
- Firebase options in `lib/firebase_options.dart`
