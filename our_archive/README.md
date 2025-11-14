# OurArchive - Flutter Application

This directory contains the main Flutter application for **OurArchive**.

For project information, setup instructions, and documentation, see the [root README](../README.md).

## Project Structure

```
our_archive/
├── lib/
│   ├── main.dart              # Application entry point
│   ├── core/sync/             # Offline sync queue
│   ├── data/
│   │   ├── models/            # Data models
│   │   ├── services/          # Business logic
│   │   └── repositories/      # Data access
│   ├── providers/             # Riverpod state management
│   ├── ui/screens/            # UI screens
│   └── debug/                 # Debug tools
├── test/                      # Test files
├── firebase/                  # Firebase configuration
└── pubspec.yaml               # Dependencies
```

## Quick Commands

```bash
# Install dependencies
fvm flutter pub get

# Run app
fvm flutter run

# Run tests (use flutter, NOT dart test)
fvm flutter test

# Analyze code
fvm flutter analyze

# Build APK (debug)
fvm flutter build apk --debug

# Build APK (release)
fvm flutter build apk --release
```

## Documentation

See [docs/](../docs/) directory for:
- Setup guide
- Features documentation
- Development roadmap
