import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/author_auth_provider.dart';

class AuthorChangePasswordScreen extends ConsumerStatefulWidget {
  const AuthorChangePasswordScreen({super.key});

  @override
  ConsumerState<AuthorChangePasswordScreen> createState() => _AuthorChangePasswordScreenState();
}

class _AuthorChangePasswordScreenState extends ConsumerState<AuthorChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _submitting = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    final auth = ref.read(authorAuthProvider);
    try {
      await ref.read(authorAuthProvider.notifier).changePassword(
            oldPassword: auth.requiresPasswordChange ? null : _oldPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwort aktualisiert.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwort konnte nicht aktualisiert werden: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requiresPasswordChange = ref.watch(authorAuthProvider).requiresPasswordChange;
    return Scaffold(
      appBar: AppBar(title: const Text('Passwort ändern')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              children: [
                if (!requiresPasswordChange) ...[
                  TextFormField(
                    controller: _oldPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Altes Passwort',
                      suffixIcon: IconButton(
                        tooltip: _obscureOldPassword ? 'Passwort anzeigen' : 'Passwort verbergen',
                        onPressed: () => setState(() => _obscureOldPassword = !_obscureOldPassword),
                        icon: Icon(_obscureOldPassword ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                    autofillHints: const [AutofillHints.password],
                    obscureText: _obscureOldPassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Bitte altes Passwort eingeben.' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Neues Passwort',
                    suffixIcon: IconButton(
                      tooltip: _obscureNewPassword ? 'Passwort anzeigen' : 'Passwort verbergen',
                      onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                      icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  autofillHints: const [AutofillHints.newPassword],
                  obscureText: _obscureNewPassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return 'Mindestens 8 Zeichen erforderlich.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Neues Passwort wiederholen',
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirmPassword ? 'Passwort anzeigen' : 'Passwort verbergen',
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  autofillHints: const [AutofillHints.newPassword],
                  obscureText: _obscureConfirmPassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  validator: (value) {
                    if (value != _newPasswordController.text) {
                      return 'Passwörter stimmen nicht überein.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Passwort speichern'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
