import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../author/data/author_auth_provider.dart';
import 'admin_user_list_screen.dart';
import 'layer_admin_tree.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  void _openUserList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'AdminUserListScreen'),
        builder: (context) => const AdminUserListScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authorAuthProvider);
    if (!auth.isLoggedIn || !auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(child: Text('Kein Zugriff auf den Admin-Bereich.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin-Bereich'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Alle Nutzer'),
                subtitle:
                    const Text('Autoren und Admins verwalten, Rechte prüfen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openUserList,
              ),
            ),
          ),
          const Expanded(child: LayerAdminTree()),
        ],
      ),
    );
  }
}
