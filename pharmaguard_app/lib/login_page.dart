import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart'; // Ensure this imports your AppColors

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLogin = true;
  String selectedRole = 'Pharmacy'; // Default signup role (Customer removed from auth)
  
  // Controllers for Login
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  // Additional Controllers for Signup
  final TextEditingController nameController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();

  Color getRoleColor() {
    if (selectedRole == 'Manufacturer') return AppColors.accentTeal;
    if (selectedRole == 'Admin') return AppColors.accentCoral;
    return AppColors.accentPurple; // Pharmacy
  }

  // ---------------------------------------------------------
  // BACKEND INTEGRATION LOGIC
  // ---------------------------------------------------------
  
  Future<void> handleAuth() async {
    if (isLogin) {
      await _processLogin();
    } else {
      await _processSignup();
    }
  }

  Future<void> _processLogin() async {
    // Replace with your Flask backend IP
    final url = Uri.parse('http://10.0.2.2:5000/api/login'); 
    
    try {
      /* UNCOMMENT THIS WHEN BACKEND IS READY
      final response = await http.post(url, body: {
        'email': emailController.text,
        'password': passwordController.text,
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String role = data['role']; // Backend should return 'pharmacy', 'manufacturer', or 'admin'
        Navigator.pushReplacementNamed(context, '/$role');
      } else {
        // Show error (e.g., Invalid credentials)
      }
      */

      // --- MOCK LOGIC FOR UI TESTING ---
      String email = emailController.text.toLowerCase();
      String role = 'pharmacy'; // default fallback
      if (email.contains('admin')) role = 'admin';
      if (email.contains('mfg')) role = 'manufacturer';
      
      Navigator.pushReplacementNamed(context, '/$role');
      // ---------------------------------

    } catch (e) {
      print("Login error: $e");
    }
  }

  Future<void> _processSignup() async {
    final url = Uri.parse('http://10.0.2.2:5000/api/signup');
    
    try {
      /* UNCOMMENT THIS WHEN BACKEND IS READY
      final response = await http.post(url, body: {
        'role': selectedRole.toLowerCase(),
        'email': emailController.text,
        'password': passwordController.text,
        'business_name': nameController.text,
        'license_number': licenseController.text,
      });
      
      if (response.statusCode == 201) { // 201 Created
        // Route them directly to their new dashboard
        Navigator.pushReplacementNamed(context, '/${selectedRole.toLowerCase()}');
      }
      */

      // --- MOCK LOGIC FOR UI TESTING ---
      Navigator.pushReplacementNamed(context, '/${selectedRole.toLowerCase()}');
      // ---------------------------------

    } catch (e) {
      print("Signup error: $e");
    }
  }

  // ---------------------------------------------------------
  // UI BUILDERS
  // ---------------------------------------------------------

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
            boxShadow: isActive ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : [],
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
            maxHeight: 850,
            constraints: const BoxConstraints(maxWidth: 420),
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
                // Header
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
                Text(isLogin ? 'Welcome back to the network' : 'Register your business on the network', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 24),
                
                // Signup-specific fields (Role selection & Business details)
                if (!isLogin) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        buildRoleTab('Pharmacy'),
                        buildRoleTab('Manufacturer'),
                        buildRoleTab('Admin'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: selectedRole == 'Admin' ? 'ADMIN FULL NAME' : 'BUSINESS / FACILITY NAME'
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: licenseController,
                    decoration: InputDecoration(
                      labelText: selectedRole == 'Admin' ? 'CLEARANCE / INVITATION CODE' : 'REGISTRATION / LICENSE NUMBER'
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 32),
                ],

                // Common Login/Signup Fields
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'EMAIL ADDRESS / ID'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'PASSWORD'),
                ),
                const SizedBox(height: 24),
                
                // Submit Button
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
                      isLogin ? 'Authenticate →' : 'Register Account →',
                      style: const TextStyle(color: AppColors.bg, fontFamily: 'Syne', fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Toggle Login/Signup
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin ? 'Register a new facility' : 'Already registered? Sign in',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ),

                const Divider(color: AppColors.border, height: 32),

                // Customer Bypass Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.accentBlue, size: 18),
                    label: const Text(
                      'I am a Customer (Track Medicine)',
                      style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
                    ),
                    onPressed: () {
                      // Bypass auth and go straight to the customer tracking page
                      Navigator.pushReplacementNamed(context, '/customer');
                    },
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
