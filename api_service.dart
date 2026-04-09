// lib/services/api_service.dart
// All HTTP calls to the Flask backend.
// ⚠️ Change baseUrl to match where your Flask server is running.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ── Change this to your Flask server IP ──────────────────────────────────
  // Android emulator  → 'http://10.0.2.2:5000'
  // iOS simulator / desktop → 'http://localhost:5000'
  // Real device on WiFi     → 'http://192.168.x.x:5000'
  static const String baseUrl = 'http://10.0.2.2:5000';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Batches ───────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getMyBatches() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$baseUrl/api/manufacturer/batches'), headers: headers);
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as Map<String, dynamic>)['batches'] as List<dynamic>? ?? [];
    }
    throw Exception('Failed to load batches: ${res.statusCode}');
  }

  static Future<Map<String, dynamic>> createBatch({
    required int medicineId,
    required String mfgDate,
    required String expiryDate,
  }) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/manufacturer/batches'),
      headers: headers,
      body: jsonEncode({'medicine_id': medicineId, 'mfg_date': mfgDate, 'expiry_date': expiryDate}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Transfer ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> transferBatch({
    required int batchId,
    required int receiverId,
  }) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/manufacturer/transfer'),
      headers: headers,
      body: jsonEncode({'batch_id': batchId, 'receiver_id': receiverId}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getTransferHistory() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$baseUrl/api/manufacturer/transfers'), headers: headers);
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as Map<String, dynamic>)['transfers'] as List<dynamic>? ?? [];
    }
    throw Exception('Failed to load transfers: ${res.statusCode}');
  }

  // ── Medicines ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getMedicines() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$baseUrl/api/medicines'), headers: headers);
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as Map<String, dynamic>)['medicines'] as List<dynamic>? ?? [];
    }
    throw Exception('Failed to load medicines: ${res.statusCode}');
  }

  // ── Pharmacies ────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getPharmacies() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$baseUrl/api/pharmacies'), headers: headers);
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as Map<String, dynamic>)['pharmacies'] as List<dynamic>? ?? [];
    }
    throw Exception('Failed to load pharmacies: ${res.statusCode}');
  }
}
