import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';

class IncomingTransfersScreen extends StatefulWidget {
  const IncomingTransfersScreen({super.key});

  @override
  State<IncomingTransfersScreen> createState() =>
      _IncomingTransfersScreenState();
}

class _IncomingTransfersScreenState extends State<IncomingTransfersScreen> {
  List<dynamic> _transfers = [];
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
      final resp = await ApiClient.instance.dio
          .get('/api/pharmacy/transfers/incoming');
      setState(() => _transfers = resp.data as List);
    } on DioException catch (e) {
      setState(
          () => _error = (e.response?.data as Map?)?['error'] ?? e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(int transferId, bool accept) async {
    final qtyCtrl = TextEditingController(text: '0');
    if (accept) {
      // Ask for quantity
      final confirmed = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Accept Transfer'),
          content: TextField(
            controller: qtyCtrl,
            decoration:
                const InputDecoration(labelText: 'Quantity to receive'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(qtyCtrl.text) ?? 0),
              child: const Text('Accept'),
            ),
          ],
        ),
      );
      if (confirmed == null) return;
      try {
        await ApiClient.instance.dio.post(
          '/api/pharmacy/transfers/$transferId/accept',
          data: {'quantity': confirmed},
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Transfer accepted!')));
      } on DioException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              (e.response?.data as Map?)?['error'] ?? 'Error accepting transfer'),
        ));
      }
    } else {
      try {
        await ApiClient.instance.dio
            .post('/api/pharmacy/transfers/$transferId/reject');
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Transfer rejected.')));
      } on DioException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              (e.response?.data as Map?)?['error'] ?? 'Error rejecting transfer'),
        ));
      }
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Transfers'),
        leading: BackButton(onPressed: () => context.go('/pharmacy')),
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
              : _transfers.isEmpty
                  ? const Center(child: Text('No pending transfers.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _transfers.length,
                        itemBuilder: (_, i) {
                          final t =
                              _transfers[i] as Map<String, dynamic>;
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.local_shipping,
                                  color: Colors.blue),
                              title: Text(
                                  '${t['brand_name']} (${t['generic_name']})'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('From: ${t['sender_username']}'),
                                  Text('Status: ${t['status']}'),
                                  Text('Date: ${t['transfer_date']}'),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle,
                                        color: Colors.green),
                                    tooltip: 'Accept',
                                    onPressed: () => _respond(
                                        t['transfer_id'], true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel,
                                        color: Colors.red),
                                    tooltip: 'Reject',
                                    onPressed: () => _respond(
                                        t['transfer_id'], false),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
