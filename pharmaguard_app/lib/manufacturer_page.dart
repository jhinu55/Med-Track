import 'package:flutter/material.dart';
import 'dart:math';
import 'main.dart'; // Import AppColors

class ManufacturerPage extends StatefulWidget {
  const ManufacturerPage({Key? key}) : super(key: key);

  @override
  _ManufacturerPageState createState() => _ManufacturerPageState();
}

class _ManufacturerPageState extends State<ManufacturerPage> {
  String activePage = 'dashboard';
  String? generatedHash;
  String? generatedBatchId;

  // Mock Data mimicking the HTML file
  final List<Map<String, dynamic>> recentBatches = [
    {'id': '#B-4821', 'medicine': 'Amoxicillin 500mg', 'expiry': '2026-08-15', 'status': 'Safe', 'color': AppColors.accentTeal},
    {'id': '#B-4820', 'medicine': 'Paracetamol 650mg', 'expiry': '2026-11-30', 'status': 'In-Transit', 'color': AppColors.accentBlue},
    {'id': '#B-4819', 'medicine': 'Metformin 500mg', 'expiry': '2025-12-01', 'status': 'Warning', 'color': AppColors.accentAmber},
    {'id': '#B-4818', 'medicine': 'Atorvastatin 10mg', 'expiry': '2027-03-20', 'status': 'Safe', 'color': AppColors.accentTeal},
    {'id': '#B-4817', 'medicine': 'Cetirizine 10mg', 'expiry': '2025-10-05', 'status': 'Blocked', 'color': AppColors.accentCoral},
  ];

  final List<Map<String, dynamic>> transfers = [
    {'id': '#T-901', 'batch': '#B-4820', 'receiver': 'Apollo Pharmacy, Delhi', 'date': '2025-03-29', 'status': 'In-Transit', 'color': AppColors.accentBlue},
    {'id': '#T-900', 'batch': '#B-4815', 'receiver': 'MedPlus Delhi', 'date': '2025-03-28', 'status': 'Received', 'color': AppColors.accentTeal},
    {'id': '#T-899', 'batch': '#B-4810', 'receiver': 'HealthFirst Noida', 'date': '2025-03-25', 'status': 'Received', 'color': AppColors.accentTeal},
    {'id': '#T-898', 'batch': '#B-4805', 'receiver': 'CityMed Stores', 'date': '2025-03-22', 'status': 'Received', 'color': AppColors.accentTeal},
  ];

  void showToast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'DM Mono', fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void handleGenerateQR() {
    // Generates a fake SHA-256 looking string and Batch ID for the demo
    const chars = '0123456789abcdef';
    final random = Random();
    final hash = List.generate(64, (index) => chars[random.nextInt(chars.length)]).join();
    final batchId = 'B-${4800 + random.nextInt(100)}';
    
    setState(() {
      generatedHash = hash;
      generatedBatchId = batchId;
    });
    
    showToast('Batch #$batchId registered with QR hash', AppColors.accentTeal);
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
        Expanded(child: _statCard('TOTAL BATCHES', '248', AppColors.accentTeal, '↑ 12 this month')),
        const SizedBox(width: 12),
        Expanded(child: _statCard('IN TRANSIT', '34', AppColors.text, 'to 18 pharmacies')),
        const SizedBox(width: 12),
        Expanded(child: _statCard('EXPIRING SOON', '7', AppColors.accentAmber, 'within 30 days')),
        const SizedBox(width: 12),
        Expanded(child: _statCard('FLAGGED', '2', AppColors.accentCoral, 'under review')),
      ]),
      const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Recent Batches', style: TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...recentBatches.map((b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(flex: 2, child: Text(b['id'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 12, color: AppColors.text))),
                Expanded(flex: 3, child: Text(b['medicine'], style: const TextStyle(fontSize: 13, color: AppColors.muted))),
                Expanded(flex: 2, child: Text(b['expiry'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 12, color: AppColors.muted))),
                Expanded(flex: 2, child: buildBadge(b['status'], b['color'] as Color)),
              ]),
            )).toList()
          ]),
        )),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Transfer Status', style: TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _timelineItem('B-4820 → Apollo Pharmacy', 'In-Transit · 2h ago', true),
            _timelineItem('B-4815 → MedPlus Delhi', 'Received · 1d ago', true),
            _timelineItem('B-4810 → HealthFirst', 'Received · 3d ago', false),
            _timelineItem('B-4805 → CityMed Stores', 'Received · 5d ago', false),
          ]),
        ))
      ]),
    ]);
  }

  Widget _timelineItem(String title, String sub, bool active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(margin: const EdgeInsets.only(top: 4), width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? AppColors.accentTeal : AppColors.border, border: Border.all(color: AppColors.surface, width: 2))),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(sub, style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted)),
        ])
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color, String meta) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: color == AppColors.text ? AppColors.border : color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontFamily: 'Syne', fontSize: 26, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(meta, style: const TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted)),
      ]),
    );
  }

  Widget buildRegisterBatch() {
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Batch Details', style: TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Medicine Name', hintText: 'e.g. Amoxicillin 500mg')),
            const SizedBox(height: 16),
            Row(children: const [
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Batch Size (units)', hintText: '500'))),
              SizedBox(width: 16),
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Production Facility', hintText: 'Plant A, Noida'))),
            ]),
            const SizedBox(height: 16),
            Row(children: const [
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Manufacture Date', hintText: 'YYYY-MM-DD'))),
              SizedBox(width: 16),
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Expiry Date', hintText: 'YYYY-MM-DD'))),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentTeal, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: handleGenerateQR,
              child: const Text('Generate QR & Register', style: TextStyle(color: AppColors.bg, fontFamily: 'Syne', fontWeight: FontWeight.bold)),
            ),
          ]),
        )),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Generated QR Hash', style: TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.bold)),
              if (generatedHash != null) buildBadge('Ready', AppColors.accentTeal),
            ]),
            const SizedBox(height: 20),
            if (generatedHash == null)
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text('Fill the form and click generate', style: TextStyle(fontFamily: 'DM Mono', fontSize: 12, color: AppColors.muted)),
              ))
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface2, border: Border.all(color: AppColors.accentTeal.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('BATCH #$generatedBatchId REGISTERED', style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.accentTeal)),
                  const SizedBox(height: 10),
                  Text(generatedHash!, style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted)),
                ]),
              ),
          ]),
        ))
      ]),
    ]);
  }

  Widget buildShipBatch() {
    return ListView(padding: const EdgeInsets.all(24), children: [
      Container(
        width: 600,
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Initiate Transfer', style: TextStyle(fontFamily: 'Syne', fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const TextField(decoration: InputDecoration(labelText: 'Batch to Ship (ID)', hintText: '#B-4821')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Receiving Pharmacy', hintText: 'Apollo Pharmacy, Delhi')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Transport Notes', hintText: 'e.g. Cold chain required')),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentTeal, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                showToast('Transfer initiated — status set to In-Transit', AppColors.accentBlue);
                setState(() => activePage = 'transfers');
              },
              child: const Text('Initiate Transfer', style: TextStyle(color: AppColors.bg, fontFamily: 'Syne', fontWeight: FontWeight.bold)),
            )),
          ]),
        ),
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
            Expanded(flex: 2, child: Text('EXPIRY DATE', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
          ])),
          const Divider(color: AppColors.border, height: 0),
          ...recentBatches.map((b) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(flex: 2, child: Text(b['id'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 12, color: AppColors.text))),
              Expanded(flex: 3, child: Text(b['medicine'], style: const TextStyle(fontSize: 13, color: AppColors.muted))),
              Expanded(flex: 2, child: Text(b['expiry'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 12, color: AppColors.muted))),
              Expanded(flex: 2, child: buildBadge(b['status'], b['color'] as Color)),
            ]),
          )).toList(),
        ]),
      ),
    ]);
  }

  Widget buildTransfers() {
    return ListView(padding: const EdgeInsets.all(24), children: [
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Row(children: const [
            Expanded(flex: 2, child: Text('TRANSFER ID', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 2, child: Text('BATCH', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 3, child: Text('RECEIVER', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.2))),
          ])),
          const Divider(color: AppColors.border, height: 0),
          ...transfers.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(flex: 2, child: Text(t['id'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 12, color: AppColors.text))),
              Expanded(flex: 2, child: Text(t['batch'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 12, color: AppColors.muted))),
              Expanded(flex: 3, child: Text(t['receiver'], style: const TextStyle(fontSize: 13, color: AppColors.muted))),
              Expanded(flex: 2, child: Text(t['date'], style: const TextStyle(fontFamily: 'DM Mono', fontSize: 12, color: AppColors.muted))),
              Expanded(flex: 2, child: buildBadge(t['status'], t['color'] as Color)),
            ]),
          )).toList(),
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
                  Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.accentTeal, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.factory, color: AppColors.bg, size: 14)),
                  const SizedBox(width: 8),
                  const Text('PharmaGuard', style: TextStyle(fontFamily: 'Syne', fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accentTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('MANUFACTURER', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.accentTeal, letterSpacing: 1))),
              ]),
            ),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.fromLTRB(10, 8, 10, 4), child: Text('MAIN', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.5))),
                buildNavItem(Icons.grid_view_rounded, 'Overview', 'dashboard'),
                buildNavItem(Icons.inventory_2_outlined, 'My Batches', 'batches'),
                buildNavItem(Icons.add_circle_outline, 'Register Batch', 'register'),
                const Padding(padding: EdgeInsets.fromLTRB(10, 12, 10, 4), child: Text('LOGISTICS', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted, letterSpacing: 1.5))),
                buildNavItem(Icons.local_shipping_outlined, 'Transfer Log', 'transfers'),
                buildNavItem(Icons.send_outlined, 'Ship Batch', 'ship'),
              ]),
            )),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Column(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Container(width: 28, height: 28, alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.accentTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Text('MF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Syne', color: AppColors.accentTeal))),
                    const SizedBox(width: 8),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('MediCorp Ltd.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Text('manufacturer', style: TextStyle(fontFamily: 'DM Mono', fontSize: 10, color: AppColors.muted)),
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
            decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: Color(0x3000D4A0)))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_pageTitle(), style: const TextStyle(fontFamily: 'Syne', fontSize: 17, fontWeight: FontWeight.w700)),
                Text(_pageSubtitle(), style: const TextStyle(fontFamily: 'DM Mono', fontSize: 11, color: AppColors.muted)),
              ])),
              if (activePage == 'dashboard')
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () => setState(() => activePage = 'register'),
                  icon: const Icon(Icons.add, size: 16, color: AppColors.bg),
                  label: const Text('New Batch', style: TextStyle(fontFamily: 'Syne', color: AppColors.bg, fontWeight: FontWeight.bold)),
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
      case 'batches':   return buildBatches();
      case 'register':  return buildRegisterBatch();
      case 'transfers': return buildTransfers();
      case 'ship':      return buildShipBatch();
      default:          return buildDashboard();
    }
  }

  String _pageTitle() {
    switch (activePage) {
      case 'batches':   return 'My Batches';
      case 'register':  return 'Register New Batch';
      case 'transfers': return 'Transfer Log';
      case 'ship':      return 'Ship Batch';
      default:          return 'Overview';
    }
  }

  String _pageSubtitle() {
    switch (activePage) {
      case 'batches':   return 'All registered batches';
      case 'register':  return 'Create a batch and generate QR hash';
      case 'transfers': return 'All outgoing shipments';
      case 'ship':      return 'Initiate a transfer to a pharmacy';
      default:          return 'MediCorp Ltd. · License #MFG-2024-091';
    }
  }
}