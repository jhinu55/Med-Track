// lib/screens/manufacturer/manufacturer_dashboard.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme.dart';
import 'dashboard_tab.dart';
import 'batches_tab.dart';
import 'create_batch_tab.dart';
import 'transfers_tab.dart';

class ManufacturerDashboard extends StatefulWidget {
  final String username;
  final int actorId;
  const ManufacturerDashboard({super.key, required this.username, required this.actorId});

  @override
  State<ManufacturerDashboard> createState() => _ManufacturerDashboardState();
}

class _ManufacturerDashboardState extends State<ManufacturerDashboard> {
  int _currentIndex = 0;

  static const _titles = ['Dashboard', 'My Batches', 'Create Batch', 'Transfer History'];

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(username: widget.username),
      const BatchesTab(),
      const CreateBatchTab(),
      const TransfersTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.local_pharmacy, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Text(widget.username,
                style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
          ),
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: kSurface,
        indicatorColor: kPrimary.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: kPrimary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: kPrimary),
            label: 'Batches',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box, color: kPrimary),
            label: 'New Batch',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz, color: kPrimary),
            label: 'Transfers',
          ),
        ],
      ),
    );
  }
}
