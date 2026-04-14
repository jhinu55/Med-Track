import 'package:flutter/material.dart';
import 'main.dart'; // Import AppColors

import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String activePage = 'dashboard';

  final List<Map<String, dynamic>> alerts = [
    {'icon': Icons.location_on, 'title': 'Geo-Anomaly · Batch #B-4817', 'detail': 'Mumbai 10:02 → Delhi 10:11 · impossible travel', 'severity': 'HIGH', 'color': AppColors.accentCoral},
    {'icon': Icons.timer_off, 'title': 'Expired-Attempt · Batch #B-4809', 'detail': 'Apollo Pharmacy attempted sale of expired Metformin batch.', 'severity': 'HIGH', 'color': AppColors.accentCoral},
    {'icon': Icons.search, 'title': 'Counterfeit-Flag · Batch #B-4811', 'detail': 'Same QR hash scanned at two locations within 3 minutes.', 'severity': 'MEDIUM', 'color': AppColors.accentAmber},
    {'icon': Icons.timer_off, 'title': 'Expired-Attempt · Batch #B-4803', 'detail': 'MedPlus Delhi — override accepted, audit trail created.', 'severity': 'LOW', 'color': AppColors.accentBlue},
  ];

  final List<Map<String, dynamic>> batches = [
    {'id': '#B-4821', 'medicine': 'Amoxicillin 500mg', 'owner': 'Apollo Pharmacy', 'status': 'Safe', 'statusColor': AppColors.accentTeal},
    {'id': '#B-4820', 'medicine': 'Paracetamol 650mg', 'owner': 'In-Transit', 'status': 'In-Transit', 'statusColor': AppColors.accentBlue},
    {'id': '#B-4819', 'medicine': 'Metformin 500mg', 'owner': 'MedPlus Delhi', 'status': 'Warning', 'statusColor': AppColors.accentAmber},
    {'id': '#B-4817', 'medicine': 'Cetirizine 10mg', 'owner': 'CityMed Stores', 'status': 'Blocked', 'statusColor': AppColors.accentCoral},
  ];

  final List<Map<String, dynamic>> actors = [
    {'id': '1', 'username': 'medicorp_admin', 'role': 'Manufacturer', 'roleColor': AppColors.accentTeal, 'email': 'admin@medicorp.in', 'registered': '2024-01-05'},
    {'id': '5', 'username': 'apollo_delhi', 'role': 'Pharmacy', 'roleColor': AppColors.accentPurple, 'email': 'info@apollo.in', 'registered': '2024-01-10'},
    {'id': '6', 'username': 'medplus_del', 'role': 'Pharmacy', 'roleColor': AppColors.accentPurple, 'email': 'ops@medplus.in', 'registered': '2024-01-11'},
    {'id': '7', 'username': 'healthfirst_noi', 'role': 'Pharmacy', 'roleColor': AppColors.accentPurple, 'email': 'hf@noida.in', 'registered': '2024-01-14'},
    {'id': '99', 'username': 'sys_admin', 'role': 'Admin', 'roleColor': AppColors.accentCoral, 'email': 'admin@pharmaguard.io', 'registered': '2024-01-01'},
  ];

  final traceController = TextEditingController(text: '101');
  final tracePharmacyController = TextEditingController(text: '5'); 

  bool isTracing = false;
  List<dynamic> liveTraceData = [];
  String traceError = '';

  Future<void> fetchTraceback() async {
  setState(() { isTracing = true; traceError = ''; liveTraceData = []; });
  try {
    final url = Uri.parse('http://10.0.2.2:5000/api/traceback');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "batch_id": int.tryParse(traceController.text.replaceAll(RegExp(r'[^0-9]'), '')),
        "actor_id": int.tryParse(tracePharmacyController.text) ?? 5
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'Success') {
      setState(() => liveTraceData = data['steps']);
    } else {
      setState(() => traceError = data['error'] ?? 'Database Traceback Failed');
    }
  } catch (e) {
    setState(() => traceError = 'Network Error: Cannot connect to API');
  } finally {
    setState(() => isTracing = false);
  }
}
  Widget buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget buildNavItem(IconData icon, String label, String page) {
    bool isActive = activePage == page;
    return ListTile(
      leading: Icon(icon, size: 18, color: isActive ? AppColors.text : AppColors.muted),
      title: Text(label, style: TextStyle(fontSize: 13, color: isActive ? AppColors.text : AppColors.muted)),
      tileColor: isActive ? AppColors.surface2 : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      dense: true,
      onTap: () => setState(() => activePage = page),
    );
  }

  Widget buildDashboard() {
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        Expanded(child: _statCard('TOTAL BATCHES', '1,284', AppColors.text)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('ACTIVE ALERTS', '5', AppColors.accentCoral)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('FLAGGED BATCHES', '12', AppColors.accentAmber)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('ACTORS', '89', AppColors.accentTeal)),
      ]),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Live Alert Feed', style: TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...alerts.take(3).map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 16)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a['title'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(a['detail'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted)),
              ])),
              buildBadge(a['severity'], a['color'] as Color),
            ]),
          )),
        ]),
      ),
    ]);
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontFamily: 'Syne', fontSize: 26, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget buildAlertFeed() {
    return ListView(padding: const EdgeInsets.all(24), children: alerts.map((a) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 18)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a['title'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(a['detail'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted)),
        ])),
        buildBadge(a['severity'], a['color'] as Color),
      ]),
    )).toList());
  }

  Widget buildTraceback() {
    final chainNodes = ['MediCorp Ltd.\nmanufacturer', 'Dist. Hub A\ndistributor', 'Rogue Supplier\n⚠ suspicious', 'Apollo Pharmacy\nfound here'];
    return ListView(padding: const EdgeInsets.all(24), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Run Traceback Query', style: TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: traceController, decoration: const InputDecoration(labelText: 'BATCH ID'))),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCoral, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => setState(() {}),
              child: const Text('Run Traceback', style: TextStyle(color: AppColors.bg, fontFamily: 'Syne', fontWeight: FontWeight.bold)),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Chain of Custody', style: TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
            children: chainNodes.asMap().entries.expand((e) {
              final isSuspicious = e.value.contains('suspicious');
              final node = Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSuspicious ? AppColors.accentCoral.withOpacity(0.08) : AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSuspicious ? AppColors.accentCoral.withOpacity(0.4) : AppColors.border),
                ),
                child: Column(children: e.value.split('\n').map((line) => Text(line,
                  style: TextStyle(fontSize: 11, fontFamily: 'DM Mono',
                    color: (isSuspicious && line.contains('⚠')) ? AppColors.accentCoral : AppColors.text))).toList()),
              );
              return e.key < chainNodes.length - 1
                ? [node, const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 14, color: AppColors.muted))]
                : [node];
            }).toList(),
          )),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          const Text('4 hops traced · suspicious entry at step 1 (Rogue Supplier)', style: TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted)),
        ]),
      ),
    ]);
  }

  Widget buildBatches() {
    return ListView(padding: const EdgeInsets.all(24), children: [
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Row(children: const [
            Expanded(flex: 2, child: Text('BATCH ID', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 3, child: Text('MEDICINE', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 3, child: Text('CURRENT OWNER', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
          ])),
          const Divider(color: AppColors.border, height: 0),
          ...batches.map((b) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(flex: 2, child: Text(b['id'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.text))),
              Expanded(flex: 3, child: Text(b['medicine'], style: const TextStyle(fontSize: 13, color: AppColors.muted))),
              Expanded(flex: 3, child: Text(b['owner'], style: const TextStyle(fontSize: 13, color: AppColors.muted))),
              Expanded(flex: 2, child: buildBadge(b['status'], b['statusColor'] as Color)),
            ]),
          )),
        ]),
      ),
    ]);
  }

  Widget buildActors() {
    return ListView(padding: const EdgeInsets.all(24), children: [
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Row(children: const [
            Expanded(flex: 1, child: Text('ID', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 3, child: Text('USERNAME', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 2, child: Text('ROLE', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 3, child: Text('EMAIL', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 2, child: Text('REGISTERED', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
          ])),
          const Divider(color: AppColors.border, height: 0),
          ...actors.map((a) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(flex: 1, child: Text(a['id'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.text))),
              Expanded(flex: 3, child: Text(a['username'], style: const TextStyle(fontSize: 13, color: AppColors.muted))),
              Expanded(flex: 2, child: buildBadge(a['role'], a['roleColor'] as Color)),
              Expanded(flex: 3, child: Text(a['email'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted))),
              Expanded(flex: 2, child: Text(a['registered'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted))),
            ]),
          )),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        // ── Sidebar ──
        Container(
          width: 200,
          decoration: const BoxDecoration(color: AppColors.surface, border: Border(right: BorderSide(color: AppColors.border))),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.accentCoral, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.security, color: AppColors.bg, size: 14)),
                  const SizedBox(width: 8),
                  const Text('PharmaGuard', style: TextStyle(fontFamily: 'Syne', fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accentCoral.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('ADMIN', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.accentCoral, letterSpacing: 1))),
              ]),
            ),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.fromLTRB(10, 8, 10, 4), child: Text('COMMAND', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.5))),
                buildNavItem(Icons.grid_view_rounded, 'Overview', 'dashboard'),
                buildNavItem(Icons.notifications_none_rounded, 'Alert Feed', 'alerts'),
                const Padding(padding: EdgeInsets.fromLTRB(10, 12, 10, 4), child: Text('INVESTIGATION', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.5))),
                buildNavItem(Icons.search_rounded, 'Traceback', 'traceback'),
                buildNavItem(Icons.inventory_2_outlined, 'All Batches', 'batches'),
                const Padding(padding: EdgeInsets.fromLTRB(10, 12, 10, 4), child: Text('SYSTEM', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.5))),
                buildNavItem(Icons.group_outlined, 'Actors', 'actors'),
              ]),
            )),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Column(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Container(width: 28, height: 28, alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.accentCoral.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Text('AD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Syne', color: AppColors.accentCoral))),
                    const SizedBox(width: 8),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('System Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Text('clearance lvl 3', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted)),
                    ]),
                  ])),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.muted, side: const BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('← logout', style: TextStyle(fontFamily: 'DM Mono', fontSize: 12)),
                )),
              ]),
            ),
          ]),
        ),

        // ── Main Content ──
        Expanded(child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: Color(0x30FF5F5F)))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_pageTitle(), style: const TextStyle(fontFamily: 'Syne', fontSize: 17, fontWeight: FontWeight.w700)),
                Text(_pageSubtitle(), style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted)),
              ])),
              if (activePage == 'dashboard')
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.accentCoral, backgroundColor: AppColors.accentCoral.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () => setState(() => activePage = 'alerts'),
                  icon: const Icon(Icons.warning_amber_rounded, size: 16),
                  label: const Text('5 Active Alerts', style: TextStyle(fontFamily: 'DM Mono', fontSize: 12)),
                ),
            ]),
          ),
          Expanded(child: _buildBody()),
        ])),
      ]),
    );
  }

  Widget _buildBody() {
    switch (activePage) {
      case 'alerts':    return buildAlertFeed();
      case 'traceback': return buildTraceback();
      case 'batches':   return buildBatches();
      case 'actors':    return buildActors();
      default:          return buildDashboard();
    }
  }

  String _pageTitle() {
    switch (activePage) {
      case 'alerts':    return 'Alert Feed';
      case 'traceback': return 'Supply Chain Traceback';
      case 'batches':   return 'All Batches';
      case 'actors':    return 'Registered Actors';
      default:          return 'Command Center';
    }
  }

  String _pageSubtitle() {
    switch (activePage) {
      case 'alerts':    return 'Triggered anomaly and risk events';
      case 'traceback': return 'Recursive CTE — full custody chain';
      case 'batches':   return 'System-wide batch registry';
      case 'actors':    return 'All ACTOR table entries';
      default:          return 'Real-time supply chain integrity';
    }
  }
}
