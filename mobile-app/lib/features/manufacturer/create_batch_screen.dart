import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';

class CreateBatchScreen extends StatefulWidget {
  const CreateBatchScreen({super.key});

  @override
  State<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends State<CreateBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  List<dynamic> _medicines = [];
  int? _selectedMedicineId;
  DateTime? _mfgDate;
  DateTime? _expiryDate;
  bool _loading = false;
  bool _loadingMedicines = true;
  String? _error;
  String? _createdHash;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    try {
      // Reuse batches list to derive medicines from it; or call a medicines endpoint.
      // Since we don't have a /api/medicines endpoint, we'll show a manual text entry.
    } finally {
      if (mounted) setState(() => _loadingMedicines = false);
    }
  }

  Future<void> _pickDate(bool isMfg) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isMfg ? now.subtract(const Duration(days: 30)) : now.add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isMfg) {
          _mfgDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  final _medicineIdCtrl = TextEditingController();

  @override
  void dispose() {
    _medicineIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mfgDate == null || _expiryDate == null) {
      setState(() => _error = 'Please select both mfg and expiry dates.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _createdHash = null;
    });
    try {
      final resp = await ApiClient.instance.dio.post(
        '/api/manufacturer/batches',
        data: {
          'medicine_id': int.parse(_medicineIdCtrl.text),
          'mfg_date': _mfgDate!.toIso8601String().split('T').first,
          'expiry_date': _expiryDate!.toIso8601String().split('T').first,
        },
      );
      setState(() => _createdHash = resp.data['qr_code_hash']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Batch #${resp.data['batch_id']} created successfully!')),
      );
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error'] ?? e.message;
      setState(() => _error = msg?.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Batch'),
        leading: BackButton(
            onPressed: () => context.go('/manufacturer/batches')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _medicineIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Medicine ID',
                  prefixIcon: Icon(Icons.medication),
                  helperText: 'Numeric ID from MEDICINE table',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Must be a number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _DateTile(
                label: 'Manufacturing Date',
                date: _mfgDate,
                onTap: () => _pickDate(true),
              ),
              const SizedBox(height: 12),
              _DateTile(
                label: 'Expiry Date',
                date: _expiryDate,
                onTap: () => _pickDate(false),
              ),
              if (_createdHash != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('QR Code Hash:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        SelectableText(_createdHash!,
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Batch'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateTile({required this.label, this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      leading: const Icon(Icons.calendar_today),
      title: Text(label),
      subtitle: Text(
        date != null
            ? date!.toIso8601String().split('T').first
            : 'Tap to select',
      ),
      onTap: onTap,
    );
  }
}
