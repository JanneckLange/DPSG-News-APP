import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../author/data/author_auth_provider.dart';
import '../../author/presentation/author_change_password_screen.dart';
import '../../author/presentation/author_login_screen.dart';
import '../../admin/presentation/admin_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAuth = ref.watch(authorAuthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(Icons.person,
                              size: 28,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authorAuth.isLoggedIn
                                    ? (authorAuth.username ?? 'Autor')
                                    : 'Anonym',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authorAuth.isLoggedIn
                                    ? 'Accounts und Rechte'
                                    : 'Noch kein Login eingerichtet',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                            label: Text(authorAuth.isLoggedIn
                                ? 'Angemeldet'
                                : 'Nicht angemeldet')),
                        if (authorAuth.isAdmin)
                          const Chip(label: Text('Admin')),
                        if (authorAuth.requiresPasswordChange)
                          const Chip(
                              label: Text('Passwortwechsel erforderlich')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (authorAuth.isLoggedIn) ...[
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Passwort ändern'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const AuthorChangePasswordScreen(),
                          ),
                        );
                      },
                    ),
                    if (authorAuth.isAdmin) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.admin_panel_settings),
                        title: const Text('Admin-Bereich'),
                        subtitle:
                            const Text('Layer, Themen und Nutzer verwalten'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const AdminScreen()),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              style: authorAuth.isLoggedIn
                  ? FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    )
                  : null,
              onPressed: authorAuth.isLoggedIn
                  ? () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout bestätigen'),
                          content:
                              const Text('Möchtest du dich wirklich abmelden?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Abbrechen'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(authorAuthProvider.notifier).logout();
                      }
                    }
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const AuthorLoginScreen()),
                      );
                    },
              icon: Icon(authorAuth.isLoggedIn ? Icons.logout : Icons.login),
              label: Text(authorAuth.isLoggedIn ? 'Logout' : 'Autoren-Login'),
            ),
          ],
        ),
      ),
    );
  }
}
