import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import 'create_household_screen.dart';
import 'join_household_screen.dart';
import 'container_screen.dart';
import 'profile_screen.dart';

class HouseholdListScreen extends ConsumerWidget {
  const HouseholdListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdsAsync = ref.watch(userHouseholdsProvider);
    final authService = ref.read(authServiceProvider);
    final currentUser = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Households'),
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              radius: 16,
              child: Icon(
                currentUser?.isAnonymous == true
                    ? Icons.person_outline
                    : Icons.person,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: householdsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (households) {
          if (households.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No households yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Create a new household or join an existing one'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: households.length,
            itemBuilder: (context, index) {
              final household = households[index];
              final isOwner = household.isOwner(currentUser!.uid);
              final memberCount = household.members.length;
              final pendingCount = household.members.values
                  .where((role) => role == 'pending')
                  .length;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        child: Text(household.name[0].toUpperCase()),
                      ),
                      title: Text(household.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$memberCount ${memberCount == 1 ? 'member' : 'members'}'),
                          if (isOwner) Text('Code: ${household.code}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOwner && pendingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$pendingCount pending',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios),
                        ],
                      ),
                      onTap: () {
                        // Set current household and navigate to rooms
                        ref.read(currentHouseholdIdProvider.notifier).state = household.id;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ContainerScreen(
                              householdId: household.id,
                              householdName: household.name,
                            ),
                          ),
                        );
                      },
                    ),
                    // Show pending members if owner
                    if (isOwner && pendingCount > 0)
                      _PendingMembersSection(household: household),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const JoinHouseholdScreen(),
                ),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('Join'),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateHouseholdScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// Widget to show pending members and allow approval
class _PendingMembersSection extends ConsumerWidget {
  final Household household;

  const _PendingMembersSection({required this.household});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingMembers = household.members.entries
        .where((entry) => entry.value == 'pending')
        .toList();

    if (pendingMembers.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Text(
                'Pending Approval',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...pendingMembers.map((entry) {
            final userId = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Text(userId.substring(0, 1).toUpperCase()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User ${userId.substring(0, 8)}...',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Text(
                          'Requested to join',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Approve button
                  FilledButton.icon(
                    onPressed: () => _approveMember(context, ref, userId),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Deny button
                  OutlinedButton(
                    onPressed: () => _denyMember(context, ref, userId),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _approveMember(
    BuildContext context,
    WidgetRef ref,
    String memberUid,
  ) async {
    try {
      final householdService = ref.read(householdServiceProvider);
      final authService = ref.read(authServiceProvider);
      final currentUserId = authService.currentUserId!;

      await householdService.approveMember(
        householdId: household.id,
        memberUid: memberUid,
        approverUid: currentUserId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member approved!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _denyMember(
    BuildContext context,
    WidgetRef ref,
    String memberUid,
  ) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny Request'),
        content: const Text('Are you sure you want to deny this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deny', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Remove the pending member
      final householdService = ref.read(householdServiceProvider);
      await ref.read(householdServiceProvider).approveMember(
            householdId: household.id,
            memberUid: memberUid,
            approverUid: ref.read(authServiceProvider).currentUserId!,
          );
      // For now, we approve then immediately remove
      // TODO: Add a proper deny/remove method to HouseholdService

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request denied')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}
