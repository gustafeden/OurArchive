# OurArchive Project Overview

## Purpose
OurArchive is a household inventory management app that helps families organize and track their belongings across rooms, shelves, boxes, and other containers.

## Tech Stack
- **Framework**: Flutter (SDK ^3.9.0)
- **Version Management**: FVM (Flutter Version Management)
- **Backend**: Firebase (Auth, Firestore, Storage, Crashlytics)
- **State Management**: Riverpod (flutter_riverpod ^2.6.1)
- **Image Handling**: image_picker, cached_network_image, flutter_image_compress
- **Additional**: mobile_scanner (barcode), csv export, share_plus, local notifications

## Project Structure
```
our_archive/lib/
├── core/
│   └── sync/           # Sync queue for offline-first functionality
├── data/
│   ├── models/         # Data models (Item, Container, Household)
│   ├── repositories/   # Data access layer
│   └── services/       # Business logic services
├── providers/          # Riverpod providers
├── ui/
│   └── screens/        # UI screens
├── debug/              # Debug utilities
└── main.dart           # App entry point
```

## Key Features
- Anonymous & email authentication
- Household creation with shareable codes
- Member approval system
- Hierarchical container organization (rooms → shelves → boxes)
- Item creation with photos
- Offline-first sync queue
- Search functionality
