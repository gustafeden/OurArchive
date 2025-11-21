import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/item.dart';
import 'providers.dart';

/// State for book-specific filters in Cover Wall
class BookFilterState {
  final Set<String> selectedCategories; // fiction, non-fiction, sci-fi, etc.
  final String? selectedAuthor;
  final bool showOnlyWithCovers;
  final String? selectedReadingStatus; // 'read', 'reading', 'to-read', etc.
  final BookSortOption sortOption;

  const BookFilterState({
    this.selectedCategories = const {},
    this.selectedAuthor,
    this.showOnlyWithCovers = false,
    this.selectedReadingStatus,
    this.sortOption = BookSortOption.title,
  });

  BookFilterState copyWith({
    Set<String>? selectedCategories,
    String? selectedAuthor,
    bool? clearAuthor = false,
    bool? showOnlyWithCovers,
    String? selectedReadingStatus,
    bool? clearReadingStatus = false,
    BookSortOption? sortOption,
  }) {
    return BookFilterState(
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedAuthor: clearAuthor!
          ? null
          : (selectedAuthor ?? this.selectedAuthor),
      showOnlyWithCovers: showOnlyWithCovers ?? this.showOnlyWithCovers,
      selectedReadingStatus: clearReadingStatus!
          ? null
          : (selectedReadingStatus ?? this.selectedReadingStatus),
      sortOption: sortOption ?? this.sortOption,
    );
  }

  bool get hasActiveFilters =>
      selectedCategories.isNotEmpty ||
      selectedAuthor != null ||
      showOnlyWithCovers ||
      selectedReadingStatus != null;
}

enum BookSortOption {
  title,
  author,
  year,
  recentlyAdded,
  pageCount,
}

// Book filter state provider
final bookFilterStateProvider = StateProvider<BookFilterState>(
  (ref) => const BookFilterState(),
);

// All book items across all user households
final allBooksItemsProvider = StreamProvider<List<Item>>((ref) async* {
  final userHouseholdsAsync = ref.watch(userHouseholdsProvider);
  final households = userHouseholdsAsync.value ?? [];

  if (households.isEmpty) {
    yield [];
    return;
  }

  final itemRepo = ref.watch(itemRepositoryProvider);

  // For simplicity, we'll just listen to the first household's stream
  // and periodically fetch from all households
  // A production app would want proper stream merging, but this works for MVP
  if (households.length == 1) {
    // Single household - use stream directly
    await for (final items in itemRepo.getItems(households[0].id)) {
      final bookItems = items
          .where((item) => item.type == 'book' && !item.archived)
          .toList();
      yield bookItems;
    }
  } else {
    // Multiple households - fetch all items periodically
    // Note: This is a simple approach; in production you'd want to properly merge streams
    await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
      final allBookItems = <Item>[];

      for (final household in households) {
        try {
          final items = await itemRepo.getItems(household.id).first;
          final bookItems = items.where(
            (item) => item.type == 'book' && !item.archived,
          );
          allBookItems.addAll(bookItems);
        } catch (e) {
          // Skip household if fetch fails
          continue;
        }
      }

      yield allBookItems;
    }
  }
});

// Book items for a specific household
final householdBooksItemsProvider =
    StreamProvider.family<List<Item>, String>((ref, householdId) {
  if (householdId.isEmpty) {
    return Stream.value([]);
  }

  final itemRepo = ref.watch(itemRepositoryProvider);
  return itemRepo.getItems(householdId).map((items) {
    return items
        .where((item) => item.type == 'book' && !item.archived)
        .toList();
  });
});

// Filtered book items (applies category, author, and sort filters)
final filteredBooksItemsProvider =
    Provider.family<List<Item>, String?>((ref, householdId) {
  // Get book items (all or specific household)
  final bookItems = householdId == null
      ? (ref.watch(allBooksItemsProvider).value ?? [])
      : (ref.watch(householdBooksItemsProvider(householdId)).value ?? []);

  final filterState = ref.watch(bookFilterStateProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

  // Apply filters
  var filtered = bookItems.where((item) {
    // Search filter
    if (searchQuery.isNotEmpty) {
      final titleMatch = item.title.toLowerCase().contains(searchQuery);
      final authorMatch = item.authors
              ?.any((author) => author.toLowerCase().contains(searchQuery)) ??
          false;
      final publisherMatch =
          item.publisher?.toLowerCase().contains(searchQuery) ?? false;
      final isbnMatch = item.isbn?.toLowerCase().contains(searchQuery) ?? false;

      if (!titleMatch && !authorMatch && !publisherMatch && !isbnMatch) {
        return false;
      }
    }

    // Category filter
    if (filterState.selectedCategories.isNotEmpty) {
      // Check if item has any of the selected categories
      final itemCategories = _extractCategories(item);
      final hasMatchingCategory = itemCategories.any(
        (cat) => filterState.selectedCategories.contains(cat),
      );
      if (!hasMatchingCategory) {
        return false;
      }
    }

    // Author filter
    if (filterState.selectedAuthor != null) {
      final hasAuthor = item.authors?.any(
            (author) => author
                .toLowerCase()
                .contains(filterState.selectedAuthor!.toLowerCase()),
          ) ??
          false;
      if (!hasAuthor) {
        return false;
      }
    }

    // Show only with covers filter
    if (filterState.showOnlyWithCovers) {
      if (item.coverUrl == null || item.coverUrl!.isEmpty) {
        return false;
      }
    }

    // Reading status filter (if using tags for this)
    if (filterState.selectedReadingStatus != null) {
      final hasStatus = item.tags?.contains(filterState.selectedReadingStatus) ?? false;
      if (!hasStatus) {
        return false;
      }
    }

    return true;
  }).toList();

  // Apply sorting
  switch (filterState.sortOption) {
    case BookSortOption.title:
      filtered.sort((a, b) => a.title.compareTo(b.title));
      break;

    case BookSortOption.author:
      filtered.sort((a, b) {
        final authorA = a.authors?.isNotEmpty == true ? a.authors!.first : '';
        final authorB = b.authors?.isNotEmpty == true ? b.authors!.first : '';
        if (authorA == authorB) {
          return a.title.compareTo(b.title);
        }
        return authorA.compareTo(authorB);
      });
      break;

    case BookSortOption.year:
      filtered.sort((a, b) {
        final yearA = int.tryParse(a.releaseYear ?? '0') ?? 0;
        final yearB = int.tryParse(b.releaseYear ?? '0') ?? 0;
        if (yearA == yearB) {
          return a.title.compareTo(b.title);
        }
        return yearB.compareTo(yearA); // Newest first
      });
      break;

    case BookSortOption.recentlyAdded:
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;

    case BookSortOption.pageCount:
      filtered.sort((a, b) {
        final pagesA = a.pageCount ?? 0;
        final pagesB = b.pageCount ?? 0;
        if (pagesA == pagesB) {
          return a.title.compareTo(b.title);
        }
        return pagesB.compareTo(pagesA); // Most pages first
      });
      break;
  }

  return filtered;
});

// Helper function to extract categories from a book item
// Categories can come from metadata or tags
List<String> _extractCategories(Item item) {
  final categories = <String>{};

  // From description or metadata (if stored)
  // This could be enhanced to parse from item.description or custom fields
  // For now, we'll use tags as categories
  if (item.tags != null) {
    categories.addAll(item.tags!);
  }

  // You could also store categories in a custom field if needed
  // Example: item.customFields['categories']

  return categories.toList();
}

// Provider for all unique categories in the book collection
final bookCategoriesProvider = Provider.family<List<String>, String?>((ref, householdId) {
  final bookItems = householdId == null
      ? (ref.watch(allBooksItemsProvider).value ?? [])
      : (ref.watch(householdBooksItemsProvider(householdId)).value ?? []);

  final categories = <String>{};
  for (final item in bookItems) {
    categories.addAll(_extractCategories(item));
  }

  final categoryList = categories.toList();
  categoryList.sort();
  return categoryList;
});

// Provider for all unique authors in the book collection
final bookAuthorsProvider = Provider.family<List<String>, String?>((ref, householdId) {
  final bookItems = householdId == null
      ? (ref.watch(allBooksItemsProvider).value ?? [])
      : (ref.watch(householdBooksItemsProvider(householdId)).value ?? []);

  final authors = <String>{};
  for (final item in bookItems) {
    if (item.authors != null && item.authors!.isNotEmpty) {
      authors.addAll(item.authors!);
    }
  }

  final authorList = authors.toList();
  authorList.sort();
  return authorList;
});

// Provider for book count
final bookCountProvider = Provider.family<int, String?>((ref, householdId) {
  final books = householdId == null
      ? (ref.watch(allBooksItemsProvider).value ?? [])
      : (ref.watch(householdBooksItemsProvider(householdId)).value ?? []);
  return books.length;
});
