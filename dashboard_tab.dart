// lib/screens/manufacturer/dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../theme.dart';

class DashboardTab extends StatefulWidget {
  final String username;
  const DashboardTab({super.key, required this.username});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _loading = true;
  String? _error;
  int _totalBatches = 0, _activeBatches = 0, _expiredBatches = 0,
      _expiringSoon = 0, _totalTransfers = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rawBatches = await ApiService.getMyBatches();
      final batches = rawBatches.map((j) => Batch.fromJson(j as Map<String, dynamic>)).toList();
      final rawTransfers = await ApiService.getTransferHistory();
      setState(() {
        _totalBatches   = batches.length;
        _expiredBatches = batches.where((b) => b.isExpired).length;
        _expiringSoon   = batches.where((b) => b.isExpiringSoon).length;
        _activeBatches  = _totalBatches - _expiredBatches;
        _totalTransfers = rawTransfers.length;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Welcome banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [kPrimary, Color(0xFF1976D2)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Icon(Icons.factory, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Welcome back,', style: TextStyle(color: Colors.white70)),
                    Text(widget.username, style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(DateFormat('EEEE, d MMM y').format(DateTime.now()),
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                )),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Stats grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              children: [
                _StatCard(label: 'Total Batches',  value: '$_totalBatches',  icon: Icons.inventory_2,   color: kPrimary),
                _StatCard(label: 'Active Batches', value: '$_activeBatches', icon: Icons.check_circle,  color: kSuccess),
                _StatCard(label: 'Expiring Soon',  value: '$_expiringSoon',  icon: Icons.warning_amber, color: kWarning),
                _StatCard(label: 'Expired',        value: '$_expiredBatches',icon: Icons.cancel,        color: kDanger),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _StatCard(
              label: 'Total Transfers Sent', value: '$_totalTransfers',
              icon: Icons.local_shipping, color: kAccent, wide: true,
            ),
          ),
          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Batch Status Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          _StatusBar(
            total: _totalBatches,
            active: _activeBatches - _expiringSoon,
            expiringSoon: _expiringSoon,
            expired: _expiredBatches,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool wide;
  const _StatCard({required this.label, required this.value, required this.icon,
      required this.color, this.wide = false});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: kSurface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: kCardShadow, blurRadius: 6, offset: Offset(0, 2))],
    ),
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 26),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: wide ? 28 : 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      )),
    ]),
  );
}

class _StatusBar extends StatelessWidget {
  final int total, active, expiringSoon, expired;
  const _StatusBar({required this.total, required this.active,
      required this.expiringSoon, required this.expired});

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('No batches yet.', style: TextStyle(color: Colors.grey)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(children: [
            if (active > 0) Expanded(flex: active, child: Container(height: 18, color: kSuccess)),
            if (expiringSoon > 0) Expanded(flex: expiringSoon, child: Container(height: 18, color: kWarning)),
            if (expired > 0) Expanded(flex: expired, child: Container(height: 18, color: kDanger)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Legend(color: kSuccess, label: 'Active ($active)'),
            _Legend(color: kWarning, label: 'Expiring ($expiringSoon)'),
            _Legend(color: kDanger,  label: 'Expired ($expired)'),
          ],
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color; final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 12, height: 12,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 12)),
  ]);
}

class _ErrorView extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: kDanger, size: 48),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: onRetry,
          icon: const Icon(Icons.refresh), label: const Text('Retry')),
    ]),
  ));
}
