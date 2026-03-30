import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/network/api_client.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _scanController = MobileScannerController();
  bool _scanning = true;
  bool _processing = false;
  String? _lastHash;
  Map<String, dynamic>? _result;
  String? _error;

  final _qtyCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _scanController.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  String _truncateHash(String? hash) {
    if (hash == null) return '';
    return hash.substring(0, hash.length > 20 ? 20 : hash.length);
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_scanning || _processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;

    setState(() {
      _scanning = false;
      _lastHash = value;
    });
    _scanController.stop();
  }

  Future<void> _processSale() async {
    if (_lastHash == null) return;
    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });
    try {
      final resp = await ApiClient.instance.dio.post(
        '/api/scan_batch',
        data: {
          'qr_hash': _lastHash,
          'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
        },
      );
      setState(() => _result = resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final body = e.response?.data;
      setState(() => _error =
          (body is Map ? body['error'] ?? body['reason'] : null) ??
              e.message);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _reset() {
    setState(() {
      _scanning = true;
      _lastHash = null;
      _result = null;
      _error = null;
    });
    _scanController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR / Process Sale'),
        leading: BackButton(onPressed: () => context.go('/pharmacy')),
        actions: [
          if (!_scanning)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan again',
              onPressed: _reset,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_scanning)
            Expanded(
              flex: 3,
              child: MobileScanner(
                controller: _scanController,
                onDetect: _onDetect,
              ),
            )
          else
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code, size: 60, color: Colors.white),
                      const SizedBox(height: 12),
                      Text(
                        'Hash: ${_truncateHash(_lastHash)}…',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_lastHash != null && _result == null && _error == null) ...[
                    TextField(
                      controller: _qtyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Quantity to dispense',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _processing ? null : _processSale,
                      icon: _processing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sell),
                      label: const Text('Process Sale'),
                    ),
                  ],
                  if (_result != null) ...[
                    _ResultCard(data: _result!),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Another'),
                    ),
                  ],
                  if (_error != null) ...[
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Try Again'),
                    ),
                  ],
                  if (_scanning && _lastHash == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'Point camera at a MedTrack QR code',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ResultCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final allowed = data['allowed'] == true;
    return Card(
      color: allowed ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(allowed ? Icons.check_circle : Icons.cancel,
                  color: allowed ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Text(
                allowed ? 'Sale Approved' : 'Sale Blocked',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: allowed ? Colors.green : Colors.red,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text('Status: ${data['status'] ?? data['reason'] ?? 'Unknown'}'),
            if (data['batch_id'] != null)
              Text('Batch ID: ${data['batch_id']}'),
            Text('Source: ${data['source'] ?? 'api'}'),
          ],
        ),
      ),
    );
  }
}
