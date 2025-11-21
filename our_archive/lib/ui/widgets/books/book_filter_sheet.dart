import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/book_providers.dart';

/// Bottom sheet for filtering and sorting books
class BookFilterSheet extends ConsumerStatefulWidget {
  const BookFilterSheet({super.key});

  @override
  ConsumerState<BookFilterSheet> createState() => _BookFilterSheetState();
}

class _BookFilterSheetState extends ConsumerState<BookFilterSheet> {
  late BookFilterState _localState;

  @override
  void initState() {
    super.initState();
    _localState = ref.read(bookFilterStateProvider);
  }

  void _applyFilters() {
    ref.read(bookFilterStateProvider.notifier).state = _localState;
    Navigator.pop(context);
  }

  void _resetFilters() {
    setState(() {
      _localState = const BookFilterState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter & Sort',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSortSection(theme),
                    const SizedBox(height: 24),
                    _buildDisplayOptionsSection(theme),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Apply button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sort By',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildSortOption(
          'Title',
          BookSortOption.title,
          Icons.sort_by_alpha,
        ),
        _buildSortOption(
          'Author',
          BookSortOption.author,
          Icons.person,
        ),
        _buildSortOption(
          'Year',
          BookSortOption.year,
          Icons.calendar_today,
        ),
        _buildSortOption(
          'Recently Added',
          BookSortOption.recentlyAdded,
          Icons.access_time,
        ),
        _buildSortOption(
          'Page Count',
          BookSortOption.pageCount,
          Icons.menu_book,
        ),
      ],
    );
  }

  Widget _buildSortOption(String label, BookSortOption option, IconData icon) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: Radio<BookSortOption>(
        value: option,
        groupValue: _localState.sortOption,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _localState = _localState.copyWith(sortOption: value);
            });
          }
        },
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: () {
        setState(() {
          _localState = _localState.copyWith(sortOption: option);
        });
      },
    );
  }

  Widget _buildDisplayOptionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Display Options',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _localState.showOnlyWithCovers,
          onChanged: (value) {
            setState(() {
              _localState = _localState.copyWith(showOnlyWithCovers: value);
            });
          },
          title: const Row(
            children: [
              Icon(Icons.image, size: 20),
              SizedBox(width: 12),
              Text('Show only books with covers'),
            ],
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
