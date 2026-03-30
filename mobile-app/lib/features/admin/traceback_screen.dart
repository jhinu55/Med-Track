import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';

class TracebackScreen extends StatefulWidget {
  const TracebackScreen({super.key});

  @override
  State<TracebackScreen> createState() => _TracebackScreenState();
}

class _TracebackScreenState extends State<TracebackScreen> {
  final _batchIdCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void dispose() {
    _batchIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final batchId = _batchIdCtrl.text.trim();
    if (batchId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final resp = await ApiClient.instance.dio.get(
        '/api/admin/traceback',
        queryParameters: {'batch_id': batchId},
      );
      setState(() => _data = resp.data as Map<String, dynamic>);
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
        title: const Text('Batch Traceback'),
        leading: BackButton(onPressed: () => context.go('/admin')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _batchIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Batch ID',
                    prefixIcon: Icon(Icons.search),
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loading ? null : _search,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Search'),
              ),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_data != null) ...[
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionCard(
                        title: 'Batch Info',
                        children: (_data!['batch'] as Map<String, dynamic>)
                            .entries
                            .map((e) => _kv(e.key, e.value?.toString() ?? ''))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Transfer History (${(_data!['transfers'] as List).length})',
                        children: (_data!['transfers'] as List).map((t) {
                          final m = t as Map<String, dynamic>;
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.swap_horiz),
                            title: Text(
                                '${m['sender_username']} → ${m['receiver_username']}'),
                            subtitle: Text(
                                '${m['status']} on ${m['transfer_date']}'),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Scan History (${(_data!['scans'] as List).length})',
                        children: (_data!['scans'] as List).map((s) {
                          final m = s as Map<String, dynamic>;
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.qr_code_scanner),
                            title: Text('By: ${m['scanned_by_username']}'),
                            subtitle: Text(
                                'GPS: ${m['gps_lat']}, ${m['gps_long']} at ${m['scan_timestamp']}'),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Alerts (${(_data!['alerts'] as List).length})',
                        children: (_data!['alerts'] as List).map((a) {
                          final m = a as Map<String, dynamic>;
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.warning_amber,
                                color: Colors.orange),
                            title: Text(
                                '${m['alert_type']} — ${m['severity']}'),
                            subtitle: Text('${m['alert_timestamp']}'),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String key, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(key,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold)),
            const Divider(),
            if (children.isEmpty)
              const Text('None', style: TextStyle(color: Colors.grey))
            else
              ...children,
          ],
        ),
      ),
    );
  }
}
