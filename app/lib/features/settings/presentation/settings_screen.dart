import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/feedback_service.dart';
import '../../author/data/author_auth_provider.dart';
import '../../profile/presentation/profile_screen.dart';
import 'app_settings_screen.dart';
import 'confetti_overlay.dart';
import 'debug_tools_screen.dart';
import 'notification_settings_screen.dart';
import 'dv_selection_screen.dart';

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
                  unawaited(ref.read(analyticsServiceProvider).trackUiClick('app_settings_entry', screen: 'settings', action: 'open', target: 'app_settings'));
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'AppSettingsScreen'),
                      builder: (context) => const AppSettingsScreen(),
                    ),
                  );
                },
              ),
              _buildNavigationTile(
                context,
                icon: Icons.notifications_active,
                title: 'Benachrichtigungen',
                subtitle: 'Praeferenzen und DV-/Topic-Auswahl',
                onTap: () {
                  unawaited(ref.read(analyticsServiceProvider).trackUiClick('notifications_entry', screen: 'settings', action: 'open', target: 'notifications'));
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: const RouteSettings(
                          name: 'NotificationSettingsScreen'),
                      builder: (context) =>
                          const NotificationSettingsScreen(),
                    ),
                  );
                },
              ),
              _buildNavigationTile(
                context,
                icon: Icons.map_outlined,
                title: 'DV-Auswahl',
                subtitle: 'Diözesanverbände und Favoriten',
                onTap: () {
                  unawaited(ref.read(analyticsServiceProvider).trackUiClick('dv_selection_entry', screen: 'settings', action: 'open', target: 'dv_selection'));
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'DvSelectionScreen'),
                      builder: (context) => const DvSelectionScreen(),
                    ),
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
                icon: Icons.feedback_outlined,
                title: 'Feedback senden',
                subtitle: 'Teile Ideen oder Probleme mit uns',
                onTap: () async {
                  await openFeedbackFlow(context, ref, screen: 'settings');
                },
              ),
              _buildNavigationTile(
                context,
                icon: Icons.developer_mode,
                title: 'Debug & Tools',
                subtitle: 'Logs, Diagnose und Referenzen',
                onTap: () {
                  unawaited(ref.read(analyticsServiceProvider).trackUiClick('debug_tools_entry', screen: 'settings', action: 'open', target: 'debug_tools'));
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'DebugToolsScreen'),
                      builder: (context) => const DebugToolsScreen(),
                    ),
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
    final authorAuth = ref.watch(authorAuthProvider);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          unawaited(
            ref.read(analyticsServiceProvider).trackUiClick(
              'profile_card',
              screen: 'settings',
              action: 'open',
              target: 'profile',
            ),
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: 'ProfileScreen'),
              builder: (context) => const ProfileScreen(),
            ),
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
                    Text(
                      authorAuth.isLoggedIn ? (authorAuth.username ?? 'Autor') : 'Profil',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authorAuth.isLoggedIn ? 'Accounts und Rechte' : 'Anonym',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      authorAuth.isLoggedIn ? 'Passwort, Logout und Admin-Bereich hier' : 'Login über Profil verfügbar',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
