import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import 'create_household_screen.dart';
import 'join_household_screen.dart';
import 'container_screen.dart';
import 'item_list_screen.dart';
import 'profile_screen.dart';
import 'scan_to_check_screen.dart';

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
                      trailing: isOwner && pendingCount > 0
                        ? Container(
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
                          )
                        : null,
                    ),
                    // Show pending members if owner
                    if (isOwner && pendingCount > 0)
                      _PendingMembersSection(household: household),

                    // Navigation buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                ref.read(currentHouseholdIdProvider.notifier).state = household.id;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ItemListScreen(
                                      household: household,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.list),
                              label: const Text('View Items'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () {
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
                              icon: const Icon(Icons.inventory_2),
                              label: const Text('Organize'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scan to Check button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ScanToCheckScreen(
                                householdId: household.id,
                                householdName: household.name,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan to Check Books'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ),
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
            return _PendingMemberRow(
              userId: userId,
              onApprove: () => _approveMember(context, ref, userId),
              onDeny: () => _denyMember(context, ref, userId),
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
    // Capture the navigator before async operations
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Approving member...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final householdService = ref.read(householdServiceProvider);
      final authService = ref.read(authServiceProvider);
      final currentUserId = authService.currentUserId!;

      await householdService.approveMember(
        householdId: household.id,
        memberUid: memberUid,
        approverUid: currentUserId,
      );

      // Close loading dialog
      navigator.pop();

      // Show success snackbar
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Member approved successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog
      navigator.pop();

      // Show error snackbar
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to approve member: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
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

    if (!context.mounted) return;

    // Capture the navigator before async operations
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Denying request...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final householdService = ref.read(householdServiceProvider);
      final authService = ref.read(authServiceProvider);
      final currentUserId = authService.currentUserId!;

      await householdService.removeMember(
        householdId: household.id,
        memberUid: memberUid,
        removerUid: currentUserId,
      );

      // Close loading dialog
      navigator.pop();

      // Show success snackbar
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Request denied successfully'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog
      navigator.pop();

      // Show error snackbar
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to deny request: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }
}

class _PendingMemberRow extends ConsumerWidget {
  final String userId;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  const _PendingMemberRow({
    required this.userId,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider(userId));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: userProfileAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, stack) {
          // Show email from Firebase Auth as fallback
          final authService = ref.read(authServiceProvider);
          final email = authService.currentUser?.email ?? 'User ${userId.substring(0, 8)}...';
          return _buildRow(context, email, null);
        },
        data: (profile) {
          String displayName;
          if (profile == null) {
            // Profile doesn't exist, show truncated ID
            displayName = 'User ${userId.substring(0, 8)}...';
          } else {
            // Try displayName, then email, then truncated ID
            displayName = profile['displayName'] as String? ??
                         profile['email'] as String? ??
                         'User ${userId.substring(0, 8)}...';
          }
          return _buildRow(context, displayName, profile);
        },
      ),
    );
  }

  Widget _buildRow(BuildContext context, String displayName, Map<String, dynamic>? profile) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          child: Text(displayName[0].toUpperCase()),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
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
          onPressed: onApprove,
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
          onPressed: onDeny,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          child: const Icon(Icons.close, size: 16),
        ),
      ],
    );
  }
}
