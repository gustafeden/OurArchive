# OurArchive

> A home for the things we share

**OurArchive** is a collaborative household inventory management app that helps families and friends track items through an intuitive, hierarchical organization system.

## Key Features

- 📦 **Hierarchical Organization** - Rooms → Shelves → Boxes (infinitely nestable)
- 👥 **Household Sharing** - Create households with unique 6-character invite codes
- 📸 **Photo Management** - Capture and store item photos with automatic compression
- 📚 **ISBN Barcode Scanner** - Automatically populate book details from barcodes
- 🔍 **Smart Search** - Find items quickly with filters by type, container, and tags
- 🔒 **Role-Based Access** - Owner, Member, Viewer, and Pending roles with approval system
- 📱 **Offline-First** - Works without internet, syncs when connection is restored
- 🔐 **Secure** - Firebase Authentication with email/password and anonymous sign-in

## Tech Stack

- **Flutter/Dart** - Cross-platform mobile framework
- **Firebase** - Authentication, Firestore database, Cloud Storage, Crashlytics
- **Riverpod** - State management
- **Material Design 3** - Modern, clean UI

## Quick Start

### For Developers

1. **Clone and install dependencies:**
   ```bash
   git clone https://github.com/yourusername/OurArchive.git
   cd OurArchive/our_archive
   fvm flutter pub get
   ```

2. **Set up Firebase:**
   - See [docs/SETUP.md](docs/SETUP.md) for detailed Firebase configuration

3. **Run the app:**
   ```bash
   fvm flutter run
   ```

4. **Run tests:**
   ```bash
   fvm flutter test
   ```

See [QUICK_START.md](QUICK_START.md) for detailed development setup.

## Documentation

- **[Setup Guide](docs/SETUP.md)** - Firebase configuration and deployment
- **[Features](docs/FEATURES.md)** - Complete feature documentation
- **[Roadmap](docs/ROADMAP.md)** - Development plans and timeline
- **[Project Guidelines](CLAUDE.md)** - Development guidelines and conventions

## Project Status

**Current:** Beta - Core features complete, ready for testing

## License

[Add license information here]

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
