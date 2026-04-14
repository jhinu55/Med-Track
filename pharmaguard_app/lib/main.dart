import 'package:flutter/material.dart';
import 'admin_page.dart';
import 'login_page.dart';
import 'customer_page.dart';
import 'pharmacy_page.dart';
import 'manufacturer_page.dart';

void main() {
  runApp(const PharmaGuardApp());
}

// Map of the CSS variables to Flutter Colors
class AppColors {
  static const bg = Color(0xFF0A0D0F);
  static const surface = Color(0xFF111518);
  static const surface2 = Color(0xFF181D21);
  static const border = Color(0x1AFFFFFF); // #ffffff0f
  static const text = Color(0xFFE8EAEC);
  static const muted = Color(0xFF6B7680);
  
  static const accentTeal = Color(0xFF00D4A0);
  static const accentPurple = Color(0xFFA78BFA);
  static const accentCoral = Color(0xFFFF5F5F);
  static const accentBlue = Color(0xFF4DA6FF);

  static const accentAmber = Color(0xFFFFB020); 
  static const muted2 = Color(0xFF828D96);
}

class PharmaGuardApp extends StatelessWidget {
  const PharmaGuardApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaGuard',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.accentTeal,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.text, fontFamily: 'DM Sans'),
          titleLarge: TextStyle(color: AppColors.text, fontFamily: 'Syne', fontWeight: FontWeight.w700),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface2,
          labelStyle: const TextStyle(color: AppColors.muted, fontFamily: 'DM Mono', fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accentTeal),
          ),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/customer': (context) => const CustomerPage(),
        '/pharmacy': (context) => const PharmacyPage(),
        '/admin': (context) => const AdminPage(),
        '/manufacturer': (context) => const ManufacturerPage(),
      },
    );
  }
}