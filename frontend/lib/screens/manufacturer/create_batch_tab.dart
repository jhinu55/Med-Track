// lib/screens/manufacturer/create_batch_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../theme.dart';

class CreateBatchTab extends StatefulWidget {
  const CreateBatchTab({super.key});
  @override
  State<CreateBatchTab> createState() => _CreateBatchTabState();
}

class _CreateBatchTabState extends State<CreateBatchTab> {
  final _formKey = GlobalKey<FormState>();
  List<Medicine> _medicines = [];
  Medicine? _selectedMedicine;
  DateTime? _mfgDate, _expiryDate;
  bool _loadingMeds = true, _submitting = false;
  String? _error;
  Map<String, dynamic>? _successData;

  final _fmt = DateFormat('yyyy-MM-dd');
  final _displayFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() { super.initState(); _loadMedicines(); }

  Future<void> _loadMedicines() async {
    try {
      final raw = await ApiService.getMedicines();
      setState(() {
        _medicines = raw.map((j) => Medicine.fromJson(j as Map<String, dynamic>)).toList();
        _loadingMeds = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load medicines: $e'; _loadingMeds = false; });
    }
  }

  Future<void> _pickDate({required bool isMfg}) async {
    final initial = isMfg ? (_mfgDate ?? DateTime.now())
        : (_expiryDate ?? DateTime.now().add(const Duration(days: 365)));
    final first = isMfg ? DateTime(2020) : (_mfgDate ?? DateTime.now());
    final last = isMfg ? DateTime.now() : DateTime.now().add(const Duration(days: 3650));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial),
      firstDate: first, lastDate: last,
    );
    if (picked != null) setState(() {
      if (isMfg) { _mfgDate = picked; if (_expiryDate?.isBefore(picked) ?? false) _expiryDate = null; }
      else _expiryDate = picked;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMedicine == null || _mfgDate == null || _expiryDate == null) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    setState(() { _submitting = true; _error = null; _successData = null; });
    try {
      final res = await ApiService.createBatch(
        medicineId: _selectedMedicine!.medicineId,
        mfgDate: _fmt.format(_mfgDate!),
        expiryDate: _fmt.format(_expiryDate!),
      );
      setState(() {
        _successData = res; _submitting = false;
        _selectedMedicine = null; _mfgDate = null; _expiryDate = null;
      });
    } catch (e) {
      setState(() { _error = 'Failed to create batch: $e'; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimary.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.add_box, color: kPrimary, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text(
                'Register a new medicine batch.\nA unique QR code hash will be auto-generated.',
                style: TextStyle(fontSize: 13, color: kPrimary),
              )),
            ]),
          ),
          const SizedBox(height: 24),

          if (_successData != null) _SuccessCard(data: _successData!),
          if (_error != null && _successData == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kDanger.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kDanger.withOpacity(0.4)),
                ),
                child: Text(_error!, style: const TextStyle(color: kDanger)),
              ),
            ),

          const Text('Medicine *', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _loadingMeds
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<Medicine>(
                  value: _selectedMedicine,
                  hint: const Text('Select a medicine'),
                  decoration: const InputDecoration(),
                  items: _medicines.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text('${m.brandName} (${m.genericName})',
                          overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _selectedMedicine = v),
                  validator: (v) => v == null ? 'Please select a medicine' : null,
                ),
          const SizedBox(height: 20),

          const Text('Manufacture Date *', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _DateField(value: _mfgDate, hint: 'Select manufacture date',
              displayFmt: _displayFmt, onTap: () => _pickDate(isMfg: true)),
          const SizedBox(height: 20),

          const Text('Expiry Date *', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _DateField(value: _expiryDate, hint: 'Select expiry date',
              displayFmt: _displayFmt, onTap: () => _pickDate(isMfg: false)),
          const SizedBox(height: 32),

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: (_loadingMeds || _submitting) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(_submitting ? 'Creating…' : 'Create Batch'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime? value; final String hint;
  final DateFormat displayFmt; final VoidCallback onTap;
  const _DateField({required this.value, required this.hint,
      required this.displayFmt, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: kSurface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today, color: kPrimary, size: 20),
        const SizedBox(width: 10),
        Text(value != null ? displayFmt.format(value!) : hint,
            style: TextStyle(color: value != null ? Colors.black87 : Colors.grey.shade500)),
      ]),
    ),
  );
}

class _SuccessCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SuccessCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final batchId = data['batch_id'] ?? '—';
    final qrHash = (data['qr_code_hash'] ?? '—').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSuccess.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSuccess.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.check_circle, color: kSuccess),
          SizedBox(width: 8),
          Text('Batch Created!', style: TextStyle(color: kSuccess, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Text('Batch ID: #$batchId', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('QR Hash: ${qrHash.length > 20 ? '${qrHash.substring(0, 20)}…' : qrHash}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      ]),
    );
  }
}
