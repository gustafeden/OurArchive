import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';

/// Reusable container selector dropdown field with AsyncValue handling
class ContainerSelectorField extends ConsumerWidget {
  final String? selectedContainerId;
  final ValueChanged<String?> onChanged;
  final String? labelText;

  const ContainerSelectorField({
    super.key,
    required this.selectedContainerId,
    required this.onChanged,
    this.labelText = 'Container (optional)',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final containersAsync = ref.watch(allContainersProvider);

    return containersAsync.when(
      data: (containers) => DropdownButtonFormField<String>(
        value: selectedContainerId,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.place),
        ),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('No container'),
          ),
          ...containers.map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.name),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Failed to load containers'),
    );
  }
}
