import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/auth_service.dart';
import '../data/services/household_service.dart';
import '../data/services/container_service.dart';
import '../data/repositories/item_repository.dart';
import '../core/sync/sync_queue.dart';
import '../data/models/household.dart';
import '../data/models/item.dart';
import '../data/models/container.dart' as model;

// Core services
final authServiceProvider = Provider((ref) => AuthService());
final householdServiceProvider = Provider((ref) => HouseholdService());
final containerServiceProvider = Provider((ref) => ContainerService());
final syncQueueProvider = Provider((ref) => SyncQueue());

final itemRepositoryProvider = Provider((ref) {
  final syncQueue = ref.watch(syncQueueProvider);
  return ItemRepository(syncQueue);
});

// Current user
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
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

  return items.where((item) {
    if (searchQuery.isNotEmpty &&
        !item.searchText.contains(searchQuery.toLowerCase())) {
      return false;
    }

    if (selectedType != null && item.type != selectedType) {
      return false;
    }

    return !item.archived;
  }).toList();
});

// UI state
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedTypeProvider = StateProvider<String?>((ref) => null);

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
  if (parentId.isEmpty) return Stream.value(<model.Container>[]);

  final containerService = ref.watch(containerServiceProvider);
  return containerService.getChildContainers(parentId);
});

// All containers in current household (flat list)
final allContainersProvider = StreamProvider<List<model.Container>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId.isEmpty) return Stream.value(<model.Container>[]);

  final containerService = ref.watch(containerServiceProvider);
  return containerService.getAllContainers(householdId);
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
