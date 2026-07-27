import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../author/data/author_auth_provider.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import 'admin_user_detail_screen.dart';

class AdminUserListScreen extends ConsumerStatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  ConsumerState<AdminUserListScreen> createState() =>
      _AdminUserListScreenState();
}

class _AdminUserListScreenState extends ConsumerState<AdminUserListScreen> {
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
    if (!auth.isAdmin) {
      if (!mounted || requestId != _usersRequestId) return;
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
      final users =
          await ref.read(authorAuthProvider.notifier).callAuthenticated(
                (token) => ref
                    .read(sync_service.remoteEventSourceProvider)
                    .fetchAdminUsers(token: token),
              );
      if (!mounted || requestId != _usersRequestId) return;
      setState(() => _users = users);
    } on StateError {
      if (!mounted || requestId != _usersRequestId) return;
      setState(() => _error = 'Kein Zugriff');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alle Nutzer'),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
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
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    );
  }
}
