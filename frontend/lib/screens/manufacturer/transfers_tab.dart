// lib/screens/manufacturer/transfers_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../theme.dart';

class TransfersTab extends StatefulWidget {
  const TransfersTab({super.key});
  @override
  State<TransfersTab> createState() => _TransfersTabState();
}

class _TransfersTabState extends State<TransfersTab> {
  List<TransferLog> _transfers = [];
  bool _loading = true;
  String? _error;
  String _filterStatus = 'All';

  static const _statuses = ['All', 'Initiated', 'In-Transit', 'Received', 'Rejected'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await ApiService.getTransferHistory();
      setState(() {
        _transfers = raw.map((j) => TransferLog.fromJson(j as Map<String, dynamic>)).toList()
          ..sort((a, b) => b.transferDate.compareTo(a.transferDate));
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<TransferLog> get _filtered =>
      _filterStatus == 'All' ? _transfers
          : _transfers.where((t) => t.status == _filterStatus).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorRetry(message: _error!, onRetry: _load);

    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: _statuses.map((s) {
            final selected = _filterStatus == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(s),
                selected: selected,
                selectedColor: kPrimary.withOpacity(0.15),
                checkmarkColor: kPrimary,
                labelStyle: TextStyle(
                  color: selected ? kPrimary : Colors.grey.shade700,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => setState(() => _filterStatus = s),
              ),
            );
          }).toList(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Text('${_filtered.length} transfer(s)',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _filtered.isEmpty
              ? const Center(child: Text('No transfers found.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _TransferCard(transfer: _filtered[i]),
                ),
        ),
      ),
    ]);
  }
}

class _TransferCard extends StatelessWidget {
  final TransferLog transfer;
  const _TransferCard({required this.transfer});

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Received':   return Icons.check_circle;
      case 'In-Transit': return Icons.local_shipping;
      case 'Rejected':   return Icons.cancel;
      default:           return Icons.send;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final color = statusColor(transfer.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15), shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(_statusIcon(transfer.status), color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Transfer #${transfer.transferId}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              _StatusChip(status: transfer.status, color: color),
            ]),
            const SizedBox(height: 8),
            _Detail(icon: Icons.inventory_2_outlined, label: 'Batch',
                value: transfer.brandName != null
                    ? '${transfer.brandName} (#${transfer.batchId})'
                    : '#${transfer.batchId}'),
            const SizedBox(height: 4),
            _Detail(icon: Icons.store, label: 'To',
                value: transfer.receiverUsername ?? 'Pharmacy #${transfer.receiverId}'),
            const SizedBox(height: 4),
            _Detail(icon: Icons.access_time, label: 'Date',
                value: fmt.format(transfer.transferDate)),
          ])),
        ]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status; final Color color;
  const _StatusChip({required this.status, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(status, style: TextStyle(
        color: color, fontWeight: FontWeight.w600, fontSize: 11)),
  );
}

class _Detail extends StatelessWidget {
  final IconData icon; final String label, value;
  const _Detail({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: Colors.grey.shade500),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
    ],
  );
}

class _ErrorRetry extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});
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
