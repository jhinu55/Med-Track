import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  List<dynamic> _batches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp =
          await ApiClient.instance.dio.get('/api/manufacturer/batches');
      setState(() => _batches = resp.data as List);
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
        title: const Text('My Batches'),
        leading: BackButton(onPressed: () => context.go('/manufacturer')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/manufacturer/batches/new'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _batches.isEmpty
                  ? const Center(child: Text('No batches found.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _batches.length,
                        itemBuilder: (_, i) {
                          final b = _batches[i] as Map<String, dynamic>;
                          final status = b['batch_status'] ?? 'Active';
                          return Card(
                            child: ListTile(
                              leading: _statusIcon(status),
                              title: Text(
                                  '${b['brand_name']} (${b['generic_name']})'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Batch #${b['batch_id']}'),
                                  Text('Expires: ${b['expiry_date']}'),
                                  Text(
                                    'Hash: ${(b['qr_code_hash'] as String).substring(0, 16)}…',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(status),
                                backgroundColor: _statusColor(status),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'BLOCKED':
        return const Icon(Icons.block, color: Colors.red);
      case 'WARNING':
        return const Icon(Icons.warning, color: Colors.orange);
      default:
        return const Icon(Icons.check_circle, color: Colors.green);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'BLOCKED':
        return Colors.red.shade100;
      case 'WARNING':
        return Colors.orange.shade100;
      default:
        return Colors.green.shade100;
    }
  }
}
