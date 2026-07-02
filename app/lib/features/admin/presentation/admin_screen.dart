import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../author/data/author_auth_provider.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import 'admin_otp_dialog.dart';
import 'admin_user_detail_screen.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  List<Map<String, dynamic>> _users = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final auth = ref.read(authorAuthProvider);
    final token = auth.token;
    if (token == null || !auth.isAdmin) {
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() => _users = users);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createUser() async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => const _CreateUserDialog(),
    );
    if (result == null) {
      return;
    }

    final auth = ref.read(authorAuthProvider);
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      final response = await remote.createAdminUser(
        token: auth.token!,
        username: result['username'] as String,
        isAdmin: result['isAdmin'] == true,
      );
      if (!mounted) {
        return;
      }
      await _loadUsers();
      if (!mounted) {
        return;
      }
      await showAdminOtpDialog(
        context,
        otp: response['oneTimePassword'] as String,
        title: 'Nutzer angelegt',
        message: 'Bitte diese Daten jetzt sicher speichern.',
        username: result['username'] as String,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nutzer konnte nicht angelegt werden: $error')),
      );
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createUser,
        icon: const Icon(Icons.person_add),
        label: const Text('Nutzer anlegen'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 240), Center(child: CircularProgressIndicator())],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!))],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final isActive = user['isActive'] as bool? ?? false;
                      return Card(
                        child: ListTile(
                          onTap: () => _openDetails(user),
                          title: Text(user['username'] as String? ?? ''),
                          subtitle: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text(isActive ? 'Aktiv' : 'Deaktiviert')),
                              if (user['isAdmin'] == true) const Chip(label: Text('Admin')),
                              if (user['requiresPasswordChange'] == true) const Chip(label: Text('Reset offen')),
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

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isAdmin = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop({
      'username': _usernameController.text.trim(),
      'isAdmin': _isAdmin,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Nutzer anlegen'),
      content: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.done,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Bitte Username eingeben.' : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isAdmin,
                onChanged: (value) => setState(() => _isAdmin = value ?? false),
                title: const Text('Admin'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
