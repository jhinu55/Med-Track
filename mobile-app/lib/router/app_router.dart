import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_provider.dart';
import '../features/auth/role_select_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_manufacturer_screen.dart';
import '../features/auth/register_pharmacy_screen.dart';
import '../features/manufacturer/manufacturer_home.dart';
import '../features/manufacturer/batches_screen.dart';
import '../features/manufacturer/create_batch_screen.dart';
import '../features/manufacturer/create_transfer_screen.dart';
import '../features/pharmacy/pharmacy_home.dart';
import '../features/pharmacy/incoming_transfers_screen.dart';
import '../features/pharmacy/inventory_screen.dart';
import '../features/pharmacy/scan_screen.dart';
import '../features/admin/admin_home.dart';
import '../features/admin/alerts_screen.dart';
import '../features/admin/traceback_screen.dart';
import '../features/admin/batch_status_screen.dart';

GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final path = state.matchedLocation;

      // Public paths (no redirect needed)
      final publicPaths = ['/', '/login', '/register'];
      final isPublic = publicPaths.any((p) => path.startsWith(p));

      if (!loggedIn && !isPublic) return '/';
      if (loggedIn) {
        final role = auth.role;
        // Redirect root → role home
        if (path == '/' || path == '/login' || path.startsWith('/register')) {
          return _roleHome(role);
        }
        // Block cross-role access
        if (role == 'Manufacturer' && !path.startsWith('/manufacturer')) {
          return '/manufacturer';
        }
        if (role == 'Pharmacy' && !path.startsWith('/pharmacy')) {
          return '/pharmacy';
        }
        if (role == 'Admin' && !path.startsWith('/admin')) {
          return '/admin';
        }
      }
      return null;
    },
    routes: [
      // Public
      GoRoute(path: '/', builder: (_, __) => const RoleSelectScreen()),
      GoRoute(
        path: '/login/:role',
        builder: (_, state) {
          const validRoles = ['Manufacturer', 'Pharmacy', 'Admin'];
          final role = state.pathParameters['role'] ?? '';
          if (!validRoles.contains(role)) {
            return const RoleSelectScreen();
          }
          return LoginScreen(role: role);
        },
      ),
      GoRoute(
        path: '/register/manufacturer',
        builder: (_, __) => const RegisterManufacturerScreen(),
      ),
      GoRoute(
        path: '/register/pharmacy',
        builder: (_, __) => const RegisterPharmacyScreen(),
      ),

      // Manufacturer
      GoRoute(
        path: '/manufacturer',
        builder: (_, __) => const ManufacturerHome(),
        routes: [
          GoRoute(
            path: 'batches',
            builder: (_, __) => const BatchesScreen(),
          ),
          GoRoute(
            path: 'batches/new',
            builder: (_, __) => const CreateBatchScreen(),
          ),
          GoRoute(
            path: 'transfers/new',
            builder: (_, __) => const CreateTransferScreen(),
          ),
        ],
      ),

      // Pharmacy
      GoRoute(
        path: '/pharmacy',
        builder: (_, __) => const PharmacyHome(),
        routes: [
          GoRoute(
            path: 'transfers',
            builder: (_, __) => const IncomingTransfersScreen(),
          ),
          GoRoute(
            path: 'inventory',
            builder: (_, __) => const InventoryScreen(),
          ),
          GoRoute(
            path: 'scan',
            builder: (_, __) => const ScanScreen(),
          ),
        ],
      ),

      // Admin
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminHome(),
        routes: [
          GoRoute(
            path: 'alerts',
            builder: (_, __) => const AlertsScreen(),
          ),
          GoRoute(
            path: 'traceback',
            builder: (_, __) => const TracebackScreen(),
          ),
          GoRoute(
            path: 'batch-status',
            builder: (_, __) => const BatchStatusScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
}

String _roleHome(String? role) {
  switch (role) {
    case 'Manufacturer':
      return '/manufacturer';
    case 'Pharmacy':
      return '/pharmacy';
    case 'Admin':
      return '/admin';
    default:
      return '/';
  }
}
