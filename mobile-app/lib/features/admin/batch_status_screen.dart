import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';

class BatchStatusScreen extends StatefulWidget {
  const BatchStatusScreen({super.key});

  @override
  State<BatchStatusScreen> createState() => _BatchStatusScreenState();
}

class _BatchStatusScreenState extends State<BatchStatusScreen> {
  final _batchIdCtrl = TextEditingController();
  String _selectedStatus = 'WARNING';
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _batchIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final batchId = int.tryParse(_batchIdCtrl.text.trim());
    if (batchId == null) {
      setState(() => _error = 'Enter a valid batch ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      await ApiClient.instance.dio.post(
        '/api/admin/batches/$batchId/status',
        data: {'status': _selectedStatus},
      );
      setState(() =>
          _success = 'Batch #$batchId updated to $_selectedStatus');
    } on DioException catch (e) {
      setState(
          () => _error = (e.response?.data as Map?)?['error'] ?? e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Batch Status'),
        leading: BackButton(onPressed: () => context.go('/admin')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Set a batch status to WARNING or BLOCKED to flag suspicious '
              'or counterfeit items, or revert to Active.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _batchIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Batch ID',
                prefixIcon: Icon(Icons.inventory_2),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'New Status',
                prefixIcon: Icon(Icons.flag),
              ),
              items: const [
                DropdownMenuItem(value: 'Active', child: Text('Active')),
                DropdownMenuItem(value: 'WARNING', child: Text('WARNING')),
                DropdownMenuItem(value: 'BLOCKED', child: Text('BLOCKED')),
              ],
              onChanged: (v) => setState(() => _selectedStatus = v!),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_success != null) ...[
              const SizedBox(height: 12),
              Text(_success!, style: const TextStyle(color: Colors.green)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Update Status'),
            ),
          ],
        ),
      ),
    );
  }
}
