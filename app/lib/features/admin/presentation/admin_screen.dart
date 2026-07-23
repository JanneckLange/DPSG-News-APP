import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../author/data/author_auth_provider.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import 'admin_user_detail_screen.dart';
import 'layer_admin_screen.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  List<Map<String, dynamic>> _users = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;
  int _usersRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final requestId = ++_usersRequestId;
    final auth = ref.read(authorAuthProvider);
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (!mounted || requestId != _usersRequestId) return;
    if (token == null || !auth.isAdmin) {
      setState(() {
        _loading = false;
        _error = 'Kein Zugriff';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final users = await remote.fetchAdminUsers(token: token);
      if (!mounted || requestId != _usersRequestId) return;
      setState(() => _users = users);
    } catch (error) {
      if (!mounted || requestId != _usersRequestId) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && requestId == _usersRequestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openDetails(Map<String, dynamic> user) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AdminUserDetailScreen(user: user),
      ),
    );
    if (changed == true) {
      await _loadUsers();
    }
  }

  void _openLayerAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LayerAdminScreen()),
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
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: const Text('Layer & Themen verwalten'),
                subtitle: const Text(
                    'Layer-Baum, Unterlayer und Themen anlegen, umbenennen, löschen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openLayerAdmin,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUsers,
              child: _loading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 240),
                        Center(child: CircularProgressIndicator())
                      ],
                    )
                  : _error != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(_error!))
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _users.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final isActive = user['isActive'] as bool? ?? false;
                            final isAdmin = user['isAdmin'] as bool? ?? false;
                            final scheme = Theme.of(context).colorScheme;
                            return Card(
                              child: ListTile(
                                onTap: () => _openDetails(user),
                                title: Text(user['username'] as String? ?? ''),
                                subtitle: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      label: const Text('Autor'),
                                      backgroundColor: scheme.secondaryContainer,
                                    ),
                                    if (isAdmin)
                                      Chip(
                                        label: const Text('Admin'),
                                        backgroundColor: scheme.primaryContainer,
                                      ),
                                    if (!isActive)
                                      Chip(
                                        label: const Text('Deaktiviert'),
                                        backgroundColor: scheme.errorContainer,
                                      ),
                                    if (user['requiresPasswordChange'] == true)
                                      const Chip(label: Text('Reset offen')),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
