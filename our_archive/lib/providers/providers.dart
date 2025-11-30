import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/auth_service.dart';
import '../data/services/household_service.dart';
import '../data/services/container_service.dart';
import '../data/services/book_lookup_service.dart';
import '../data/services/logger_service.dart';
import '../data/services/type_service.dart';
import '../data/services/thumbnail_preload_service.dart';
import '../services/music_lookup_service.dart';
import '../ui/services/ui_service.dart';
import '../data/repositories/item_repository.dart';
import '../data/repositories/container_repository.dart';
import '../core/sync/sync_queue.dart';
import '../data/models/household.dart';
import '../data/models/item.dart';
import '../data/models/container.dart' as model;
import '../data/models/container_type.dart';
import '../data/models/item_type.dart';

// Core services
final authServiceProvider = Provider((ref) => AuthService());
final householdServiceProvider = Provider((ref) => HouseholdService());
final containerServiceProvider = Provider((ref) => ContainerService());
final bookLookupServiceProvider = Provider((ref) => BookLookupService());
final musicLookupServiceProvider = Provider((ref) => MusicLookupService());
final syncQueueProvider = Provider((ref) => SyncQueue());
final loggerServiceProvider = Provider((ref) => LoggerService());
final typeServiceProvider = Provider((ref) => TypeService());
final uiServiceProvider = Provider((ref) => UiService());

final itemRepositoryProvider = Provider((ref) {
  final syncQueue = ref.watch(syncQueueProvider);
  return ItemRepository(syncQueue);
});

final containerRepositoryProvider = Provider((ref) => ContainerRepository());

final thumbnailPreloadServiceProvider = Provider((ref) => ThumbnailPreloadService());

// Current user
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// User profile by UID
final userProfileProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
  final authService = ref.watch(authServiceProvider);
  return authService.getUserProfile(uid);
});

// Current household
final currentHouseholdIdProvider = StateProvider<String>((ref) => '');

// User's households
final userHouseholdsProvider = StreamProvider<List<Household>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(<Household>[]);

  final householdService = ref.watch(householdServiceProvider);
  return householdService.getUserHouseholds(user.uid);
});

// Items in current household
final householdItemsProvider = StreamProvider<List<Item>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId.isEmpty) return Stream.value(<Item>[]);

  final itemRepo = ref.watch(itemRepositoryProvider);
  return itemRepo.getItems(householdId);
});

// Filtered items
final filteredItemsProvider = Provider<List<Item>>((ref) {
  final items = ref.watch(householdItemsProvider).value ?? [];
  final searchQuery = ref.watch(searchQueryProvider);
  final selectedType = ref.watch(selectedTypeProvider);
  final selectedContainer = ref.watch(selectedContainerFilterProvider);
  final selectedTag = ref.watch(selectedTagFilterProvider);
  final selectedMusicFormat = ref.watch(selectedMusicFormatProvider);

  return items.where((item) {
    if (searchQuery.isNotEmpty &&
        !item.searchText.contains(searchQuery.toLowerCase())) {
      return false;
    }

    // Handle type filtering
    if (selectedType != null && item.type != selectedType) {
      return false;
    }

    // Music format sub-filtering (only applies when viewing music type)
    if (ItemType.isMusicType(selectedType) && selectedMusicFormat != null) {
      if (item.format == null || item.format!.isEmpty) {
        return false;
      }
      final formatStr = item.format!.join(' ').toLowerCase();
      switch (selectedMusicFormat) {
        case 'cd':
          if (!formatStr.contains('cd')) return false;
          break;
        case 'vinyl':
          if (!formatStr.contains('vinyl') && !formatStr.contains('lp')) return false;
          break;
        case 'cassette':
          if (!formatStr.contains('cassette')) return false;
          break;
        case 'digital':
          if (!formatStr.contains('digital') && !formatStr.contains('file')) return false;
          break;
      }
    }

    if (selectedContainer != null) {
      if (selectedContainer == 'unorganized') {
        if (item.containerId != null) return false;
      } else if (item.containerId != selectedContainer) {
        return false;
      }
    }

    if (selectedTag != null && !item.tags.contains(selectedTag)) {
      return false;
    }

    return !item.archived;
  }).toList();
});

// UI state
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedTypeProvider = StateProvider<String?>((ref) => null);
final selectedContainerFilterProvider = StateProvider<String?>((ref) => null);
final selectedTagFilterProvider = StateProvider<String?>((ref) => null);
final selectedMusicFormatProvider = StateProvider<String?>((ref) => null);

// View mode for ItemListScreen (list vs browse)
enum ViewMode { list, browse }
final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.list);

// Expanded category sections in browse mode
final expandedCategoriesProvider = StateProvider<Set<String>>((ref) => {});

// Pending members for current household (for owners)
final pendingMembersProvider = StreamProvider<List<Map<String, String>>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId.isEmpty) return Stream.value([]);

  final householdService = ref.watch(householdServiceProvider);
  return householdService.getPendingMembers(householdId);
});

// Top-level containers (rooms) in current household
final householdContainersProvider = StreamProvider<List<model.Container>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId.isEmpty) return Stream.value(<model.Container>[]);

  final containerService = ref.watch(containerServiceProvider);
  return containerService.getTopLevelContainers(householdId);
});

// Child containers for a specific parent container
final childContainersProvider = StreamProvider.family<List<model.Container>, String>((ref, parentId) {
  final householdId = ref.watch(currentHouseholdIdProvider);

  if (parentId.isEmpty) return Stream.value(<model.Container>[]);
  if (householdId.isEmpty) return Stream.value(<model.Container>[]);

  final containerService = ref.watch(containerServiceProvider);
  return containerService.getChildContainers(parentId, householdId);
});

// All containers in current household (flat list)
final allContainersProvider = StreamProvider<List<model.Container>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId.isEmpty) return Stream.value(<model.Container>[]);

  final containerService = ref.watch(containerServiceProvider);
  return containerService.getAllContainers(householdId);
});

// All unique tags from items in current household
final allTagsProvider = Provider<List<String>>((ref) {
  final items = ref.watch(householdItemsProvider).value ?? [];
  final tagsSet = <String>{};
  for (final item in items) {
    tagsSet.addAll(item.tags);
  }
  final tags = tagsSet.toList()..sort();
  return tags;
});

// Container types for a household
final containerTypesProvider = StreamProvider.family<List<ContainerType>, String>((ref, householdId) {
  if (householdId.isEmpty) return Stream.value(<ContainerType>[]);

  final typeService = ref.watch(typeServiceProvider);
  return typeService.getContainerTypes(householdId);
});

// Item types for a household
final itemTypesProvider = StreamProvider.family<List<ItemType>, String>((ref, householdId) {
  if (householdId.isEmpty) return Stream.value(<ItemType>[]);

  final typeService = ref.watch(typeServiceProvider);
  return typeService.getItemTypes(householdId);
});

// Items in a specific container
final containerItemsProvider = StreamProvider.family<List<Item>, String?>((ref, containerId) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId.isEmpty) return Stream.value(<Item>[]);

  // Get all items in household
  final itemsAsync = ref.watch(householdItemsProvider);

  // Return stream that filters items by containerId
  return itemsAsync.when(
    data: (items) {
      if (containerId == null) {
        // Return items without any container
        return Stream.value(items.where((item) => item.containerId == null).toList());
      } else {
        // Return items in this specific container
        return Stream.value(items.where((item) => item.containerId == containerId).toList());
      }
    },
    loading: () => Stream.value(<Item>[]),
    error: (_, __) => Stream.value(<Item>[]),
  );
});

// All items in a container and all its nested child containers (recursive)
final nestedContainerItemsProvider = StreamProvider.family<List<Item>, String?>((ref, containerId) async* {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId.isEmpty) {
    yield <Item>[];
    return;
  }

  // Get all items and containers in the household
  final itemsAsync = ref.watch(householdItemsProvider);
  final allContainersAsync = ref.watch(allContainersProvider);

  await for (final items in itemsAsync.when(
    data: (items) async* {
      final containers = await allContainersAsync.when(
        data: (containers) async => containers,
        loading: () async => <model.Container>[],
        error: (_, __) async => <model.Container>[],
      );

      if (containerId == null) {
        // Return items without any container
        yield items.where((item) => item.containerId == null).toList();
      } else {
        // Get all container IDs that are descendants of this container
        final descendantIds = _getDescendantContainerIds(containerId, containers);

        // Include the parent container itself and all descendants
        final allRelevantIds = {containerId, ...descendantIds};

        // Return items in any of these containers
        yield items.where((item) =>
          item.containerId != null && allRelevantIds.contains(item.containerId)
        ).toList();
      }
    },
    loading: () => Stream.value(<Item>[]),
    error: (_, __) => Stream.value(<Item>[]),
  )) {
    yield items;
  }
});

// Helper function to recursively get all descendant container IDs
Set<String> _getDescendantContainerIds(String parentId, List<model.Container> allContainers) {
  final descendants = <String>{};
  final children = allContainers.where((c) => c.parentId == parentId).toList();

  for (final child in children) {
    descendants.add(child.id);
    // Recursively add descendants of this child
    descendants.addAll(_getDescendantContainerIds(child.id, allContainers));
  }

  return descendants;
}
