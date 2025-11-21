import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/book_providers.dart';

/// Horizontal scrolling category bar for books
class BookCategoryBar extends ConsumerWidget {
  final String? householdId;
  final VoidCallback? onCategorySelected;

  const BookCategoryBar({
    super.key,
    this.householdId,
    this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(bookCategoriesProvider(householdId));
    final filterState = ref.watch(bookFilterStateProvider);
    final theme = Theme.of(context);

    // Always show "All Books" chip
    final chips = <Widget>[
      _buildCategoryChip(
        context,
        ref,
        'All Books',
        isSelected: filterState.selectedCategories.isEmpty,
        onTap: () {
          ref.read(bookFilterStateProvider.notifier).state =
              filterState.copyWith(selectedCategories: {});
          onCategorySelected?.call();
        },
      ),
    ];

    // Add category chips
    for (final category in categories) {
      chips.add(
        _buildCategoryChip(
          context,
          ref,
          category,
          isSelected: filterState.selectedCategories.contains(category),
          onTap: () {
            // Toggle category selection
            final newCategories = Set<String>.from(filterState.selectedCategories);
            if (newCategories.contains(category)) {
              newCategories.remove(category);
            } else {
              newCategories.clear(); // Single selection mode
              newCategories.add(category);
            }

            ref.read(bookFilterStateProvider.notifier).state =
                filterState.copyWith(selectedCategories: newCategories);
            onCategorySelected?.call();
          },
        ),
      );
    }

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: categories.isEmpty
          ? Center(
              child: Text(
                'No categories',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            )
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: chips
                  .map((chip) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: chip,
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    WidgetRef ref,
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.textTheme.bodyMedium?.color,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        backgroundColor: theme.colorScheme.surface,
        selectedColor: theme.colorScheme.primary,
        checkmarkColor: theme.colorScheme.onPrimary,
        elevation: isSelected ? 2 : 0,
        pressElevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
