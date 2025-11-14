import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../data/services/log_export_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    final householdsAsync = ref.watch(userHouseholdsProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    final isAnonymous = user.isAnonymous;
    final email = user.email ?? 'Anonymous User';
    final userId = user.uid;
    final createdAt = user.metadata.creationTime;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    isAnonymous ? Icons.person_outline : Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isAnonymous ? 'Guest User' : email,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAnonymous ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isAnonymous ? 'Anonymous' : 'Registered',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Account info section
          _SectionHeader(title: 'Account Information'),

          _InfoTile(
            icon: Icons.email,
            title: 'Email',
            value: isAnonymous ? 'Not set' : email,
            subtitle: isAnonymous ? 'Sign up to secure your account' : null,
          ),

          _DisplayNameTile(userId: userId),

          _InfoTile(
            icon: Icons.fingerprint,
            title: 'User ID',
            value: '${userId.substring(0, 8)}...',
            subtitle: 'Tap to copy full ID',
            onTap: () {
              // Could add clipboard copy here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('User ID: $userId')),
              );
            },
          ),

          if (createdAt != null)
            _InfoTile(
              icon: Icons.calendar_today,
              title: 'Member Since',
              value: _formatDate(createdAt),
            ),

          // Households section
          householdsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (households) => _InfoTile(
              icon: Icons.home,
              title: 'Households',
              value: '${households.length}',
              subtitle: households.isEmpty
                  ? 'No households yet'
                  : households.map((h) => h.name).join(', '),
            ),
          ),

          const Divider(height: 32),

          // Actions section
          _SectionHeader(title: 'Actions'),

          if (isAnonymous)
            ListTile(
              leading: const Icon(Icons.upgrade, color: Colors.blue),
              title: const Text('Upgrade Account'),
              subtitle: const Text('Create an account to secure your data'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate back and show welcome screen which has sign-up
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tap "Sign in with Email" to upgrade your account'),
                  ),
                );
              },
            ),

          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.orange),
            title: const Text('Send Debug Logs'),
            subtitle: const Text('Share logs to help diagnose issues'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _sendLogs(context, ref),
          ),

          ListTile(
            leading: Icon(Icons.logout, color: Colors.red[700]),
            title: const Text('Sign Out'),
            subtitle: const Text('Sign out of your account'),
            onTap: () => _showSignOutDialog(context, ref),
          ),

          const Divider(height: 32),

          // App info section
          _SectionHeader(title: 'About'),

          const _InfoTile(
            icon: Icons.info_outline,
            title: 'Version',
            value: '1.0.0',
          ),

          const _InfoTile(
            icon: Icons.inventory_2_outlined,
            title: 'OurArchive',
            value: 'Household Inventory',
            subtitle: 'Track and share your items',
          ),

          const SizedBox(height: 32),

          // Privacy notice
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Your data is securely stored in Firebase and only accessible to you and household members you approve.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _sendLogs(BuildContext context, WidgetRef ref) {
    final logger = ref.read(loggerServiceProvider);
    final exportService = LogExportService(logger);
    exportService.showSendLogsDialog(context);
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close profile screen
              await ref.read(authServiceProvider).signOut();
            },
            child: Text(
              'Sign Out',
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _DisplayNameTile extends ConsumerStatefulWidget {
  final String userId;

  const _DisplayNameTile({required this.userId});

  @override
  ConsumerState<_DisplayNameTile> createState() => _DisplayNameTileState();
}

class _DisplayNameTileState extends ConsumerState<_DisplayNameTile> {
  bool _isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider(widget.userId));

    return userProfileAsync.when(
      loading: () => const ListTile(
        leading: Icon(Icons.person),
        title: Text('Display Name'),
        subtitle: LinearProgressIndicator(),
      ),
      error: (_, __) => _buildTile('Not set', null),
      data: (profile) {
        final displayName = profile?['displayName'] as String?;
        return _buildTile(displayName ?? 'Not set', displayName);
      },
    );
  }

  Widget _buildTile(String displayValue, String? currentName) {
    if (_isEditing) {
      return ListTile(
        leading: const Icon(Icons.person),
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => _saveName(),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _controller.clear();
                });
              },
            ),
          ],
        ),
      );
    }

    return _InfoTile(
      icon: Icons.person,
      title: 'Display Name',
      value: displayValue,
      subtitle: 'Tap to edit',
      onTap: () {
        setState(() {
          _isEditing = true;
          _controller.text = currentName ?? '';
        });
      },
    );
  }

  Future<void> _saveName() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateUserProfile(
        uid: widget.userId,
        displayName: name,
      );

      // Invalidate the provider to force a refresh
      ref.invalidate(userProfileProvider(widget.userId));

      setState(() {
        _isEditing = false;
        _controller.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
