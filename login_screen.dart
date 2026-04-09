// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'manufacturer/manufacturer_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      if (data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token'] as String);
        await prefs.setString('role', data['user']['role'] as String);
        await prefs.setString('username', data['user']['username'] as String);
        await prefs.setInt('actor_id', data['user']['actor_id'] as int);
        if (!mounted) return;
        if (data['user']['role'] == 'Manufacturer') {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => ManufacturerDashboard(
              username: data['user']['username'] as String,
              actorId: data['user']['actor_id'] as int,
            ),
          ));
        } else {
          setState(() => _error = 'This app is for Manufacturers only.');
        }
      } else {
        setState(() => _error = data['error'] as String? ?? 'Login failed.');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.local_pharmacy, size: 72, color: kPrimary),
                  const SizedBox(height: 12),
                  Text('MedTrack', textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: kPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Pharmaceutical Supply Chain', textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: Colors.grey.shade600)),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => v == null || v.isEmpty ? 'Enter username' : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kDanger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kDanger.withOpacity(0.4)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: kDanger),
                          textAlign: TextAlign.center),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Sign In'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Demo: mfr_novartis / mfr_novartis@MedTrack#2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
