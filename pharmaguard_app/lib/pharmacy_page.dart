import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart'; // Import AppColors

class PharmacyPage extends StatefulWidget {
  const PharmacyPage({Key? key}) : super(key: key);

  @override
  _PharmacyPageState createState() => _PharmacyPageState();
}

class _PharmacyPageState extends State<PharmacyPage> {
  // --- Scan Controllers & State ---
  final TextEditingController scanHashController = TextEditingController();
  bool isScanning = false;
  Map<String, dynamic>? scanResult;

  // --- Sale Controllers & State ---
  final TextEditingController batchIdController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: "1");
  final TextEditingController durationController = TextEditingController(text: "7");
  final TextEditingController overrideController = TextEditingController();
  bool isProcessing = false;

  // The hardcoded ID for Apollo Pharmacy based on your DB seed
  final int pharmacyId = 5; 

  // Using 127.0.0.1 since you are running in Chrome desktop
  final String apiUrl = 'http://127.0.0.1:5000/api';

  void showToast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'DM Mono', fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> doScan() async {
    final hash = scanHashController.text.trim();
    if (hash.isEmpty) {
      showToast('Please enter a QR Hash', AppColors.accentCoral);
      return;
    }

    setState(() {
      isScanning = true;
      scanResult = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/scan_batch'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "qr_hash": hash,
          "pharmacy_id": pharmacyId,
          "quantity": 1
        }),
      );

      setState(() {
        scanResult = jsonDecode(response.body);
        isScanning = false;
      });

      if (response.statusCode == 200 && scanResult?['allowed'] == true) {
        showToast('Scan processed via backend', AppColors.accentTeal);
      } else {
        showToast('Warning: Issue detected with batch', AppColors.accentCoral);
      }
    } catch (e) {
      setState(() => isScanning = false);
      showToast('Network Error: Could not connect to API', AppColors.accentCoral);
    }
  }

  Future<void> processSale() async {
    final batchIdStr = batchIdController.text.trim();
    final qtyStr = qtyController.text.trim();
    final durationStr = durationController.text.trim();
    final overrideReason = overrideController.text.trim();

    if (batchIdStr.isEmpty || qtyStr.isEmpty) {
      showToast('Batch ID and Quantity are required', AppColors.accentCoral);
      return;
    }

    setState(() => isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/process_sale'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "pharmacy_id": pharmacyId,
          "batch_id": int.parse(batchIdStr),
          "quantity": int.parse(qtyStr),
          "treatment_duration_days": durationStr.isNotEmpty ? int.parse(durationStr) : null,
          "override_reason": overrideReason.isNotEmpty ? overrideReason : null,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['allowed'] == true) {
        showToast('Sale committed — inventory updated', AppColors.accentTeal);
        batchIdController.clear();
        qtyController.text = "1";
        overrideController.clear();
      } else {
        showToast('DB ERROR: ${data['error'] ?? data['status']}', AppColors.accentCoral);
      }
    } catch (e) {
      showToast('Network Error: Could not connect to API', AppColors.accentCoral);
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Pharmacy Dashboard', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.muted),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600), // Keeps it centered and readable on desktop
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. SCAN QR SECTION
                // ==========================================
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SCAN QR CODE', style: TextStyle(fontFamily: 'DM Mono', fontSize: 12, color: AppColors.accentPurple, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: scanHashController,
                        decoration: const InputDecoration(labelText: 'Enter SHA-256 Hash', prefixIcon: Icon(Icons.qr_code, color: AppColors.muted)),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isScanning ? null : doScan,
                          icon: isScanning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.bg, strokeWidth: 2)) : const Icon(Icons.qr_code_scanner, color: AppColors.bg),
                          label: Text(isScanning ? 'Verifying...' : 'Verify Batch', style: const TextStyle(color: AppColors.bg, fontWeight: FontWeight.bold, fontFamily: 'Syne', fontSize: 16)),
                        ),
                      ),
                      
                      // Scan Result Display
                      if (scanResult != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scanResult!['allowed'] == true ? AppColors.accentTeal.withOpacity(0.1) : AppColors.accentCoral.withOpacity(0.1),
                            border: Border.all(color: scanResult!['allowed'] == true ? AppColors.accentTeal.withOpacity(0.3) : AppColors.accentCoral.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Scan Result:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Syne', fontSize: 16)),
                                  Text(
                                    scanResult!['status'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Syne',
                                      fontSize: 16,
                                      color: scanResult!['allowed'] == true ? AppColors.accentTeal : AppColors.accentCoral,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Allowed: ${scanResult!['allowed']}', style: const TextStyle(color: AppColors.muted, fontSize: 13, fontFamily: 'DM Mono')),
                              if (scanResult!['error'] != null) ...[
                                const SizedBox(height: 8),
                                Text('Reason: ${scanResult!['error']}', style: const TextStyle(color: AppColors.accentCoral, fontSize: 13, fontFamily: 'DM Mono')),
                              ]
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),

                // ==========================================
                // 2. PROCESS SALE SECTION
                // ==========================================
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PROCESS SALE', style: TextStyle(fontFamily: 'DM Mono', fontSize: 12, color: AppColors.accentPurple, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: batchIdController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Batch ID (e.g., 10)', prefixIcon: Icon(Icons.tag, color: AppColors.muted)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Quantity'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Treatment Duration (days)', prefixIcon: Icon(Icons.calendar_month, color: AppColors.muted)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: overrideController,
                        decoration: const InputDecoration(
                          labelText: 'Override Reason (Optional)',
                          hintText: 'Required if batch is expired',
                          prefixIcon: Icon(Icons.warning_amber_rounded, color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isProcessing ? null : processSale,
                          child: isProcessing 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.bg, strokeWidth: 2))
                            : const Text('Commit Sale Transaction', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.bold, fontFamily: 'Syne', fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}