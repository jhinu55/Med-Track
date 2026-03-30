import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.local_hospital, size: 80, color: Color(0xFF1565C0)),
              const SizedBox(height: 16),
              Text(
                'MedTrack',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Pharmaceutical Supply Chain Monitoring',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),
              Text(
                'Select your role to continue',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              _RoleTile(
                role: 'Manufacturer',
                icon: Icons.factory,
                description: 'Create batches, initiate transfers',
                onTap: () => context.go('/login/Manufacturer'),
              ),
              const SizedBox(height: 12),
              _RoleTile(
                role: 'Pharmacy',
                icon: Icons.local_pharmacy,
                description: 'Manage inventory, scan QR codes',
                onTap: () => context.go('/login/Pharmacy'),
              ),
              const SizedBox(height: 12),
              _RoleTile(
                role: 'Admin',
                icon: Icons.admin_panel_settings,
                description: 'Monitor alerts, investigate anomalies',
                onTap: () => context.go('/login/Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final String role;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  const _RoleTile({
    required this.role,
    required this.icon,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(icon, color: cs.onPrimaryContainer),
        ),
        title: Text(role, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
