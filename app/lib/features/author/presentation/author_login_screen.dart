import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/author_auth_provider.dart';
import 'author_change_password_screen.dart';

class AuthorLoginScreen extends ConsumerStatefulWidget {
  const AuthorLoginScreen({super.key});

  @override
  ConsumerState<AuthorLoginScreen> createState() => _AuthorLoginScreenState();
}

class _AuthorLoginScreenState extends ConsumerState<AuthorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authorAuthProvider.notifier).login(
            _usernameController.text.trim(),
            _passwordController.text,
          );

      if (!mounted) {
        return;
      }
      final auth = ref.read(authorAuthProvider);
      if (auth.requiresPasswordChange) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AuthorChangePasswordScreen()),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login fehlgeschlagen: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autoren-Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              children: [
                const Text('Mit Username und Passwort anmelden.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Bitte Username eingeben.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Passwort',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'Passwort anzeigen' : 'Passwort verbergen',
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  obscureText: _obscurePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  validator: (value) => value == null || value.isEmpty ? 'Bitte Passwort eingeben.' : null,
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
                      : const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
