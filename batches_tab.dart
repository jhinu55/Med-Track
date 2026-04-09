// lib/screens/manufacturer/batches_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../theme.dart';

class BatchesTab extends StatefulWidget {
  const BatchesTab({super.key});
  @override
  State<BatchesTab> createState() => _BatchesTabState();
}

class _BatchesTabState extends State<BatchesTab> {
  List<Batch> _batches = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await ApiService.getMyBatches();
      setState(() {
        _batches = raw.map((j) => Batch.fromJson(j as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Batch> get _filtered {
    if (_search.isEmpty) return _batches;
    final q = _search.toLowerCase();
    return _batches.where((b) =>
        b.brandName.toLowerCase().contains(q) ||
        b.genericName.toLowerCase().contains(q) ||
        b.batchId.toString().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorRetry(message: _error!, onRetry: _load);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          decoration: const InputDecoration(
              hintText: 'Search by medicine name or batch ID…',
              prefixIcon: Icon(Icons.search), isDense: true),
          onChanged: (v) => setState(() => _search = v),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Text('${_filtered.length} batch(es)',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _filtered.isEmpty
              ? const Center(child: Text('No batches found.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _BatchCard(batch: _filtered[i], onTransferred: _load),
                ),
        ),
      ),
    ]);
  }
}

class _BatchCard extends StatelessWidget {
  final Batch batch;
  final VoidCallback onTransferred;
  const _BatchCard({required this.batch, required this.onTransferred});

  Color get _statusColor {
    if (batch.isExpired) return kDanger;
    if (batch.isExpiringSoon) return kWarning;
    return kSuccess;
  }
  String get _statusLabel {
    if (batch.isExpired) return 'Expired';
    if (batch.isExpiringSoon) return 'Expiring Soon';
    return 'Active';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(batch.brandName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(batch.genericName,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor.withOpacity(0.4)),
              ),
              child: Text(_statusLabel, style: TextStyle(
                  color: _statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _InfoRow(icon: Icons.tag, label: 'Batch ID', value: '#${batch.batchId}'),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.calendar_today, label: 'Manufactured', value: fmt.format(batch.mfgDate)),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.event_busy, label: 'Expiry',
              value: fmt.format(batch.expiryDate), valueColor: _statusColor),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.qr_code, label: 'QR Hash',
              value: '${batch.qrCodeHash.substring(0, 12)}…'),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_2),
              label: const Text('QR Code'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Batch #${batch.batchId}'),
                  content: SizedBox(width: 200, height: 200,
                      child: QrImageView(data: batch.qrCodeHash, version: QrVersions.auto, size: 200)),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Transfer'),
              onPressed: batch.isExpired
                  ? null
                  : () => showDialog(context: context,
                      builder: (_) => _TransferDialog(batch: batch, onSuccess: onTransferred)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _TransferDialog extends StatefulWidget {
  final Batch batch; final VoidCallback onSuccess;
  const _TransferDialog({required this.batch, required this.onSuccess});
  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  List<Pharmacy> _pharmacies = [];
  Pharmacy? _selected;
  bool _loading = true, _submitting = false;
  String? _error, _success;

  @override
  void initState() { super.initState(); _fetchPharmacies(); }

  Future<void> _fetchPharmacies() async {
    try {
      final raw = await ApiService.getPharmacies();
      setState(() {
        _pharmacies = raw.map((j) => Pharmacy.fromJson(j as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Could not load pharmacies: $e'; _loading = false; });
    }
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() { _submitting = true; _error = null; });
    try {
      await ApiService.transferBatch(batchId: widget.batch.batchId, receiverId: _selected!.actorId);
      setState(() { _success = 'Transfer initiated!'; _submitting = false; });
      widget.onSuccess();
    } catch (e) {
      setState(() { _error = 'Transfer failed: $e'; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Transfer Batch #${widget.batch.batchId}'),
    content: _loading
        ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
        : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Medicine: ${widget.batch.brandName}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Select receiving pharmacy:'),
            const SizedBox(height: 8),
            DropdownButtonFormField<Pharmacy>(
              value: _selected,
              hint: const Text('Choose a pharmacy'),
              decoration: const InputDecoration(isDense: true),
              items: _pharmacies.map((p) =>
                  DropdownMenuItem(value: p, child: Text(p.username))).toList(),
              onChanged: (v) => setState(() => _selected = v),
            ),
            if (_error != null) ...[const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: kDanger, fontSize: 12))],
            if (_success != null) ...[const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.check_circle, color: kSuccess, size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text(_success!, style: const TextStyle(color: kSuccess))),
              ])],
          ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      if (_success == null)
        ElevatedButton(
          onPressed: (_selected == null || _submitting) ? null : _submit,
          child: _submitting
              ? const SizedBox(height: 16, width: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Send'),
        ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value; final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: Colors.grey.shade500),
    const SizedBox(width: 6),
    Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    Expanded(child: Text(value,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87),
        overflow: TextOverflow.ellipsis)),
  ]);
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
