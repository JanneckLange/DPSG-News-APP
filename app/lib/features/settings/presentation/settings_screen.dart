import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/presentation/profile_screen.dart';
import 'app_settings_screen.dart';
import 'confetti_overlay.dart';
import 'debug_tools_screen.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _tapCount = 0;
  DateTime? _firstTapAt;

  void _handleTripleTapInTwoSeconds() {
    final now = DateTime.now();
    if (_firstTapAt == null || now.difference(_firstTapAt!) > const Duration(seconds: 2)) {
      _firstTapAt = now;
      _tapCount = 1;
    } else {
      _tapCount++;
    }

    if (_tapCount >= 3) {
      _tapCount = 0;
      _firstTapAt = null;
      _showConfetti();
    }
  }

  void _showConfetti() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => const ConfettiOverlay());
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(context),
          const SizedBox(height: 16),
          _buildSectionHeader('Einstellungen'),
          _buildCard(
            children: [
              _buildNavigationTile(
                context,
                icon: Icons.tune,
                title: 'App-Einstellungen',
                subtitle: 'Darstellung, Sprache und Tracking',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AppSettingsScreen()),
                  );
                },
              ),
              _buildNavigationTile(
                context,
                icon: Icons.notifications_active,
                title: 'Benachrichtigungen',
                subtitle: 'Praeferenzen und DV-/Topic-Auswahl',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Debug & Tools'),
          _buildCard(
            children: [
              _buildNavigationTile(
                context,
                icon: Icons.developer_mode,
                title: 'Debug & Tools',
                subtitle: 'Logs, Diagnose und Referenzen',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const DebugToolsScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Rechtliches'),
          _buildCard(
            children: [
              _buildNavigationTile(context, icon: Icons.gavel, title: 'Impressum', onTap: () {}),
              _buildNavigationTile(context, icon: Icons.shield, title: 'Datenschutz', onTap: () {}),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(indent: 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTripleTapInTwoSeconds,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Entwickelt mit', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      SizedBox(width: 4),
                      Icon(Icons.favorite, size: 14, color: Colors.red),
                      SizedBox(width: 4),
                      Text('in Hamburg', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Version: 0.1.0',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Anonym', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 2),
                    const Text('Login später verfügbar', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }

  Widget _buildNavigationTile(
    BuildContext context, {
      required IconData icon,
      required String title,
      String? subtitle,
      Widget? trailing,
      VoidCallback? onTap,
    }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
