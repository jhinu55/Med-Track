import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart'; // Import AppColors

class CustomerPage extends StatefulWidget {
  const CustomerPage({Key? key}) : super(key: key);

  @override
  _CustomerPageState createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  final TextEditingController batchCodeController = TextEditingController();
  Map<String, dynamic>? medicineDetails;
  bool isLoading = false;
  String errorMessage = '';

  Future<void> fetchProvenanceData(String batchCode) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      medicineDetails = null;
    });

    try {
      // Connects to the Flask backend
      final url = Uri.parse('http://10.0.2.2:5000/api/track/$batchCode');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          medicineDetails = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Batch not found. Please verify the code.';
          isLoading = false;
        });
      }
    } catch (e) {
      // Mock data for UI testing if the backend isn't running
      setState(() {
        isLoading = false;
        medicineDetails = {
          'name': 'Amoxicillin 500mg',
          'manufacturer': 'MediCorp Ltd. (Plant A, Noida)',
          'pharmacy': 'Apollo Pharmacy, Delhi',
          'batchCode': batchCode,
          'status': 'Verified Safe',
          'manufacturedDate': '2024-01-10',
          'expiryDate': '2026-08-15',
        };
      });
    }
  }

  Widget buildDetailRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Verify Medicine', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.muted),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ENTER BATCH CODE', style: TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: batchCodeController,
                          decoration: const InputDecoration(hintText: 'e.g. B-4821'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => fetchProvenanceData(batchCodeController.text),
                          child: const Icon(Icons.search, color: AppColors.bg),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (isLoading) const CircularProgressIndicator(color: AppColors.accentBlue),
            
            if (errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.accentCoral.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accentCoral.withOpacity(0.3))),
                child: Text(errorMessage, style: const TextStyle(color: AppColors.accentCoral)),
              ),
              
            if (medicineDetails != null && !isLoading)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView(
                    children: [
                      const Text('Provenance Details', style: TextStyle(fontFamily: 'Syne', fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      buildDetailRow('STATUS', medicineDetails!['status'], Icons.verified_user, AppColors.accentTeal),
                      const Divider(color: AppColors.border, height: 24),
                      buildDetailRow('MEDICINE', medicineDetails!['name'], Icons.medication, AppColors.accentBlue),
                      buildDetailRow('BATCH CODE', medicineDetails!['batchCode'], Icons.qr_code, AppColors.muted),
                      buildDetailRow('MANUFACTURED BY', medicineDetails!['manufacturer'], Icons.factory, AppColors.accentTeal),
                      buildDetailRow('DISPENSED BY', medicineDetails!['pharmacy'], Icons.local_pharmacy, AppColors.accentPurple),
                      const Divider(color: AppColors.border, height: 24),
                      buildDetailRow('MFG DATE', medicineDetails!['manufacturedDate'], Icons.calendar_today, AppColors.muted),
                      buildDetailRow('EXPIRY DATE', medicineDetails!['expiryDate'], Icons.event_busy, AppColors.accentAmber),
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}