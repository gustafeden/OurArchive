import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../providers/portfolio_providers.dart';
import '../../data/services/log_export_service.dart';
import '../services/ui_service.dart';
import '../../debug/debug_screen.dart';
import 'theme_settings_screen.dart';
import 'general_settings_screen.dart';
import 'portfolio/portfolio_collections_screen.dart';

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

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: bottomPadding + 16),
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
                    isAnonymous ? Ionicons.person_outline : Ionicons.person_outline,
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
            icon: Ionicons.mail_outline,
            title: 'Email',
            value: isAnonymous ? 'Not set' : email,
            subtitle: isAnonymous ? 'Sign up to secure your account' : null,
          ),

          _DisplayNameTile(userId: userId),

          _InfoTile(
            icon: Ionicons.finger_print_outline,
            title: 'User ID',
            value: '${userId.substring(0, 8)}...',
            subtitle: 'Tap to copy full ID',
            onTap: () {
              UiService.showInfo('User ID: $userId');
            },
          ),

          if (createdAt != null)
            _InfoTile(
              icon: Ionicons.calendar_outline,
              title: 'Member Since',
              value: _formatDate(createdAt),
            ),

          // Households section
          householdsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (households) => _InfoTile(
              icon: Ionicons.home_outline,
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
              leading: const Icon(Ionicons.arrow_up_circle_outline, color: Colors.blue),
              title: const Text('Upgrade Account'),
              subtitle: const Text('Create an account to secure your data'),
              trailing: const Icon(Ionicons.chevron_forward_outline, size: 16),
              onTap: () {
                // Navigate back and show welcome screen which has sign-up
                Navigator.pop(context);
                UiService.showInfo('Tap "Sign in with Email" to upgrade your account');
              },
            ),

          ListTile(
            leading: const Icon(Ionicons.color_palette_outline, color: Colors.purple),
            title: const Text('Theme Settings'),
            subtitle: const Text('Customize app colors and appearance'),
            trailing: const Icon(Ionicons.chevron_forward_outline, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ThemeSettingsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Ionicons.settings_outline, color: Colors.teal),
            title: const Text('General Settings'),
            subtitle: const Text('Configure app preferences'),
            trailing: const Icon(Ionicons.chevron_forward_outline, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GeneralSettingsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Ionicons.bug_outline, color: Colors.orange),
            title: const Text('Send Debug Logs'),
            subtitle: const Text('Share logs to help diagnose issues'),
            trailing: const Icon(Ionicons.chevron_forward_outline, size: 16),
            onTap: () => _sendLogs(context, ref),
          ),

          // Debug Tools - only visible in debug builds
          if (kDebugMode)
            ListTile(
              leading: const Icon(Ionicons.build_outline, color: Colors.red),
              title: const Text('Debug Tools'),
              subtitle: const Text('Development and migration tools'),
              trailing: const Icon(Ionicons.chevron_forward_outline, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DebugScreen(),
                  ),
                );
              },
            ),

          // Portfolio Management - only visible to admin
          if (user.uid == portfolioAdminUid)
            ListTile(
              leading: const Icon(Ionicons.images_outline, color: Colors.indigo),
              title: const Text('Portfolio'),
              subtitle: const Text('Manage photo collections'),
              trailing: const Icon(Ionicons.chevron_forward_outline, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PortfolioCollectionsScreen(),
                  ),
                );
              },
            ),

          ListTile(
            leading: Icon(Ionicons.log_out_outline, color: Colors.red[700]),
            title: const Text('Sign Out'),
            subtitle: const Text('Sign out of your account'),
            onTap: () => _showSignOutDialog(context, ref),
          ),

          const Divider(height: 32),

          // App info section
          _SectionHeader(title: 'About'),

          const _InfoTile(
            icon: Ionicons.information_circle_outline,
            title: 'Version',
            value: '1.0.0',
          ),

          const _InfoTile(
            icon: Ionicons.cube_outline,
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
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close profile screen
              await ref.read(authServiceProvider).signOut();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
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
        leading: Icon(Ionicons.person_outline),
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
        leading: const Icon(Ionicons.person_outline),
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
              icon: const Icon(Ionicons.checkmark_outline, color: Colors.green),
              onPressed: () => _saveName(),
            ),
            IconButton(
              icon: const Icon(Ionicons.close_outline, color: Colors.red),
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
      icon: Ionicons.person_outline,
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
      UiService.showWarning('Name cannot be empty');
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
        UiService.showSuccess('Display name updated!');
      }
    } catch (e) {
      if (mounted) {
        UiService.showError('Error: ${e.toString()}');
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
