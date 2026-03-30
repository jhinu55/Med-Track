import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> _alerts = [];
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
          await ApiClient.instance.dio.get('/api/admin/alerts');
      setState(() => _alerts = resp.data as List);
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
        title: const Text('Security Alerts'),
        leading: BackButton(onPressed: () => context.go('/admin')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red)))
              : _alerts.isEmpty
                  ? const Center(child: Text('No alerts found.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _alerts.length,
                        itemBuilder: (_, i) {
                          final a = _alerts[i] as Map<String, dynamic>;
                          final severity = a['severity'] ?? 'Low';
                          return Card(
                            child: ListTile(
                              leading: _severityIcon(severity),
                              title: Text(
                                  '${a['alert_type']} — ${a['brand_name']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Batch #${a['batch_id']}'),
                                  Text('Status: ${a['batch_status']}'),
                                  Text('At: ${a['alert_timestamp']}'),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: _SeverityChip(severity: severity),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _severityIcon(String severity) {
    switch (severity) {
      case 'High':
        return const Icon(Icons.error, color: Colors.red);
      case 'Medium':
        return const Icon(Icons.warning, color: Colors.orange);
      default:
        return const Icon(Icons.info, color: Colors.blue);
    }
  }
}

class _SeverityChip extends StatelessWidget {
  final String severity;
  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (severity) {
      case 'High':
        bg = Colors.red.shade100;
        break;
      case 'Medium':
        bg = Colors.orange.shade100;
        break;
      default:
        bg = Colors.blue.shade100;
    }
    return Chip(label: Text(severity), backgroundColor: bg);
  }
}
