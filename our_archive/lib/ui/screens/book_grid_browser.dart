import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/item.dart';
import '../../providers/book_providers.dart';
import '../../providers/providers.dart';
import '../widgets/books/category_bar.dart';
import '../widgets/books/book_cover_card.dart';
import '../widgets/books/book_filter_sheet.dart';
import 'item_detail_screen.dart';
import 'book_scan_screen.dart';

/// Cover Wall grid browser for books
class BookGridBrowser extends ConsumerStatefulWidget {
  final String? householdId; // null = all households

  const BookGridBrowser({
    super.key,
    this.householdId,
  });

  @override
  ConsumerState<BookGridBrowser> createState() => _BookGridBrowserState();
}

class _BookGridBrowserState extends ConsumerState<BookGridBrowser> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _getResponsiveColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final orientation = MediaQuery.of(context).orientation;

    if (orientation == Orientation.landscape) {
      // Landscape: 5-7 columns
      if (width > 1200) return 7;
      if (width > 900) return 6;
      return 5;
    } else {
      // Portrait: 3-4 columns
      if (width > 600) return 4;
      return 3;
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BookFilterSheet(),
    );
  }

  void _navigateToAddBook() async {
    // Get household ID - if viewing all books, use current household
    String householdId = widget.householdId ?? ref.read(currentHouseholdIdProvider);

    // If still empty, get the first household
    if (householdId.isEmpty) {
      final households = await ref.read(userHouseholdsProvider.future);
      if (households.isNotEmpty) {
        householdId = households.first.id;
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookScanScreen(householdId: householdId),
      ),
    );
  }

  Future<dynamic> _getHousehold(String householdId) async {
    final households = await ref.read(userHouseholdsProvider.future);
    return households.firstWhere(
      (h) => h.id == householdId,
      orElse: () => households.first,
    );
  }

  void _handleBookTap(Item book) async {
    // Get household ID - use widget's householdId or current household
    String householdId = widget.householdId ?? ref.read(currentHouseholdIdProvider);

    // If still empty, get the first household
    if (householdId.isEmpty) {
      final households = await ref.read(userHouseholdsProvider.future);
      if (households.isNotEmpty) {
        householdId = households.first.id;
      }
    }

    final household = await _getHousehold(householdId);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailScreen(
          item: book,
          household: household,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = widget.householdId == null
        ? ref.watch(allBooksItemsProvider)
        : ref.watch(householdBooksItemsProvider(widget.householdId!));

    return booksAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Books'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: const Text('Books'),
        ),
        body: Center(child: Text('Error: $error')),
      ),
      data: (allBooks) {
        // Apply filters
        final books = ref.watch(
          filteredBooksItemsProvider(widget.householdId),
        );

        final filterState = ref.watch(bookFilterStateProvider);

        return Scaffold(
          extendBody: true,
          appBar: _buildAppBar(filterState, books.length),
          body: books.isEmpty ? _buildEmptyState() : _buildBookGrid(books),
          floatingActionButton: FloatingActionButton(
            heroTag: 'book_grid_fab',
            onPressed: _navigateToAddBook,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BookFilterState filterState, int bookCount) {
    return AppBar(
      title: Text(widget.householdId == null ? 'All Books' : 'Books'),
      actions: [
        // Search button
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            // Toggle search mode
            // This could be enhanced with a search field
          },
        ),
        // Filter button with badge if filters are active
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterSheet,
            ),
            if (filterState.hasActiveFilters)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: BookCategoryBar(
          householdId: widget.householdId,
          onCategorySelected: _scrollToTop,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final searchQuery = ref.watch(searchQueryProvider);
    final filterState = ref.watch(bookFilterStateProvider);

    if (searchQuery.isNotEmpty || filterState.hasActiveFilters) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No books found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Try adjusting your filters or search'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Clear filters
                ref.read(searchQueryProvider.notifier).state = '';
                ref.read(bookFilterStateProvider.notifier).state =
                    const BookFilterState();
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_stories, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No books yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Tap + to add your first book'),
        ],
      ),
    );
  }

  Widget _buildBookGrid(List<Item> books) {
    final columnCount = _getResponsiveColumnCount(context);

    return RefreshIndicator(
      onRefresh: () async {
        if (widget.householdId == null) {
          ref.invalidate(allBooksItemsProvider);
          await ref.read(allBooksItemsProvider.future);
        } else {
          ref.invalidate(householdBooksItemsProvider(widget.householdId!));
          await ref.read(householdBooksItemsProvider(widget.householdId!).future);
        }
      },
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68, // Portrait book ratio
        ),
        itemCount: books.length,
        itemBuilder: (context, index) {
          return BookCoverCard(
            book: books[index],
            onTap: () => _handleBookTap(books[index]),
          );
        },
      ),
    );
  }
}
