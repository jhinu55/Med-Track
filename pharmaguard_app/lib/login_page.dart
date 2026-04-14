import 'package:flutter/material.dart';
import 'main.dart'; // Import for AppColors
import 'dart:convert';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLogin = true;
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String selectedRole = 'Manufacturer';
  bool isLoading = false;

  // Matches the UI logic from the HTML script
  Color getRoleColor() {
    if (selectedRole == 'Manufacturer') return AppColors.accentTeal;
    if (selectedRole == 'Pharmacy') return AppColors.accentPurple;
    if (selectedRole == 'Admin') return AppColors.accentCoral;
    return AppColors.accentBlue; // Customer
  }

  void handleAuth() {
    // In a real scenario, this connects to the backend to verify the ID/Pass
    // and returns the user's role. Here we route based on the ID input for demo purposes.
    String route = '/customer'; 
    String idInput = idController.text.toLowerCase();
    
    if (isLogin) {
      if (idInput.contains('admin')) route = '/admin';
      else if (idInput.contains('pharm')) route = '/pharmacy';
      else if (idInput.contains('mfg')) route = '/manufacturer';
    } else {
      // If signing up, route them to the dashboard of the role they just created
      route = '/${selectedRole.toLowerCase()}';
    }

    Navigator.pushReplacementNamed(context, route);
  }

  Widget buildRoleTab(String role) {
    bool isActive = selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isActive ? [BoxShadow(color: Colors.black26, blurRadius: 4)] : [],
          ),
          alignment: Alignment.center,
          child: Text(
            role,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Syne',
              color: isActive ? getRoleColor() : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 700),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: AppColors.accentTeal, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.security, color: AppColors.bg, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('PharmaGuard', style: TextStyle(fontFamily: 'Syne', fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('SUPPLY CHAIN INTEGRITY', style: TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted, letterSpacing: 1.5)),
                const SizedBox(height: 32),
                Text(isLogin ? 'Sign in' : 'Create Account', style: const TextStyle(fontFamily: 'Syne', fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(isLogin ? 'Access your dashboard' : 'Select your role to register', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 24),
                
                if (!isLogin) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        buildRoleTab('Customer'),
                        buildRoleTab('Pharmacy'),
                        buildRoleTab('Manufacturer'),
                        buildRoleTab('Admin'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                TextField(
                  controller: idController,
                  decoration: const InputDecoration(labelText: 'USERNAME / ID'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'PASSWORD'),
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLogin ? AppColors.accentTeal : getRoleColor(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: handleAuth,
                    child: Text(
                      isLogin ? 'Enter →' : 'Sign Up →',
                      style: const TextStyle(color: AppColors.bg, fontFamily: 'Syne', fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin ? 'Need an account? Sign up' : 'Already have an account? Login',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}