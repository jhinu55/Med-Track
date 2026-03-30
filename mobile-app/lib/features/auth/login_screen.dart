import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/network/api_client.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiClient.instance.dio.post(
        '/api/auth/login',
        data: {
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text,
          'role': widget.role,
        },
      );
      final data = resp.data as Map<String, dynamic>;
      final roleId = data['manufacturer_id'] ??
          data['pharmacy_id'] ??
          data['admin_id'] ??
          data['actor_id'];
      if (!mounted) return;
      await context.read<AuthProvider>().login(
            token: data['token'],
            role: data['role'],
            actorId: data['actor_id'],
            roleSpecificId: roleId,
            username: data['username'] ?? '',
          );
      // Router redirect handles navigation
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error'] ?? e.message;
      setState(() => _error = msg?.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role} Login'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _RoleIcon(role: widget.role),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
              if (widget.role != 'Admin') ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      context.go('/register/${widget.role.toLowerCase()}'),
                  child: Text('No account? Register as ${widget.role}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleIcon extends StatelessWidget {
  final String role;
  const _RoleIcon({required this.role});

  @override
  Widget build(BuildContext context) {
    final icons = {
      'Manufacturer': Icons.factory,
      'Pharmacy': Icons.local_pharmacy,
      'Admin': Icons.admin_panel_settings,
    };
    return Icon(icons[role] ?? Icons.person, size: 64,
        color: Theme.of(context).colorScheme.primary);
  }
}
