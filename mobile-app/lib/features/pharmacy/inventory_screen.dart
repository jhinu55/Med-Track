import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<dynamic> _items = [];
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
          await ApiClient.instance.dio.get('/api/pharmacy/inventory');
      setState(() => _items = resp.data as List);
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
        title: const Text('Inventory'),
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
              : _items.isEmpty
                  ? const Center(child: Text('No inventory items.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final item =
                              _items[i] as Map<String, dynamic>;
                          final status = item['batch_status'] ?? 'Active';
                          final expiry = item['expiry_date'] ?? '';
                          final qty =
                              item['quantity_on_hand']?.toString() ?? '0';
                          return Card(
                            child: ListTile(
                              leading: _statusIcon(status),
                              title: Text(
                                  '${item['brand_name']} (${item['generic_name']})'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Batch #${item['batch_id']} | Qty: $qty'),
                                  Text('Expires: $expiry'),
                                  Text(
                                      'Price: ₹${item['base_price']}'),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: _StatusChip(status: status),
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
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (status) {
      case 'BLOCKED':
        bg = Colors.red.shade100;
        break;
      case 'WARNING':
        bg = Colors.orange.shade100;
        break;
      default:
        bg = Colors.green.shade100;
    }
    return Chip(label: Text(status), backgroundColor: bg);
  }
}
