# Code Style and Conventions

## Architecture
- **Clean Architecture**: Separation between UI, business logic, and data layers
- **Layers**:
  - `ui/screens/` - Flutter widgets and screens
  - `data/services/` - Business logic
  - `data/repositories/` - Data access
  - `data/models/` - Data models
  - `providers/` - Riverpod state management

## Naming Conventions
- Files: snake_case (e.g., `item_detail_screen.dart`)
- Classes: PascalCase (e.g., `ItemDetailScreen`)
- Variables/Functions: camelCase (e.g., `getItemById`)
- Private members: prefix with underscore (e.g., `_privateMethod`)

## State Management
- Use Riverpod providers for all state management
- Define providers in `providers/providers.dart` or co-located with features
- Follow reactive patterns

## Firebase Integration
- Authentication via AuthService
- Data persistence via Firestore
- Storage via Firebase Storage
- Offline-first with sync queue in `core/sync/`

## Design Patterns
- Repository pattern for data access
- Service pattern for business logic
- Provider pattern for state management
- Dependency injection via Riverpod
