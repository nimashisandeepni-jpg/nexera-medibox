import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class MediboxMonitorHome extends StatefulWidget {
  const MediboxMonitorHome({super.key});

  @override
  State<MediboxMonitorHome> createState() => _MediboxMonitorHomeState();
}

class _MediboxMonitorHomeState extends State<MediboxMonitorHome> {
  final _msgController = TextEditingController();

  String _selectedHour = "08";
  String _selectedMinute = "30";
  String _selectedDay = "06";
  String _selectedMonth = "06";
  String _selectedYear = "2026";

  final Map<int, int> _compartmentPillCounts = {
    1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0
  };

  final List<String> _hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));
  final List<String> _minutes = List.generate(60, (i) => i.toString().padLeft(2, '0'));
  final List<String> _days = List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
  final List<String> _months = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
  final List<String> _years = List.generate(6, (i) => (2026 + i).toString());

  Future<void> _syncToFirebase() async {
    final Map<String, dynamic> uploadPayload = {
      'hour': int.parse(_selectedHour),
      'minute': int.parse(_selectedMinute),
      'isEnabled': true,
      'pill_taken': false, // Resets banner state on deploy (Bug 3)
      'extra_message': _msgController.text.isEmpty ? "Take your medicine" : _msgController.text,
    };

    _compartmentPillCounts.forEach((key, value) {
      uploadPayload['slot_$key'] = value; // Direct flat row matching (Bug 2)
    });

    try {
      await FirebaseFirestore.instance
          .collection('medibox')
          .doc('device_01')
          .set(uploadPayload, SetOptions(merge: true));

      if (mounted) {
        _msgController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚡ Nexera Matrix Synced via Firestore!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync Failure: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('NEXERA FIRESTORE CONTROL PANEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        backgroundColor: const Color(0xFF203A43),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const NexeraLoginPage())),
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('medibox').doc('device_01').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          // Safe evaluation casting handles Bug 1 perfectly
          final rawData = snapshot.data?.data();
          final Map<String, dynamic> data = rawData is Map ? Map<String, dynamic>.from(rawData) : {};

          final int liveHour = data['hour'] ?? 0;
          final int liveMinute = data['minute'] ?? 0;
          final bool pillTaken = data['pill_taken'] ?? true;
          final String liveMsg = data['extra_message'] ?? 'None';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!pillTaken)
                  Card(
                    color: Colors.redAccent.withOpacity(0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent)),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.crisis_alert_rounded, color: Colors.redAccent),
                          SizedBox(width: 12),
                          Expanded(child: Text('ALERT: Patient has not extracted the dose from the tray yet.', style: TextStyle(fontSize: 12))),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1F353D), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LIVE CONSOLE STATUS: Scheduled for $liveHour:${liveMinute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                      const Divider(color: Colors.white10),
                      Text('Active Message: "$liveMsg"', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildCardPicker('⏱️ Hour', _buildDropdown(_selectedHour, _hours, (v) => setState(() => _selectedHour = v!)))),
                    const SizedBox(width: 10),
                    Expanded(child: _buildCardPicker('⏱️ Minute', _buildDropdown(_selectedMinute, _minutes, (v) => setState(() => _selectedMinute = v!)))),
                  ],
                ),
                const SizedBox(height: 10),
                _buildCardPicker('📆 Schedule Date', Row(
                  children: [
                    Expanded(child: _buildDropdown(_selectedDay, _days, (v) => setState(() => _selectedDay = v!))),
                    Expanded(child: _buildDropdown(_selectedMonth, _months, (v) => setState(() => _selectedMonth = v!))),
                    Expanded(child: _buildDropdown(_selectedYear, _years, (v) => setState(() => _selectedYear = v!))),
                  ],
                )),
                const SizedBox(height: 20),
                const Text('⚙️ MANUAL MATRIX MATRIX CONFIGURATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54)),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.1),
                  itemCount: 8,
                  itemBuilder: (context, index) {
                    int slotNum = index + 1;
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF1F353D).withOpacity(0.6), borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Slot $slotNum', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18), onPressed: () {
                                if (_compartmentPillCounts[slotNum]! > 0) setState(() => _compartmentPillCounts[slotNum] = _compartmentPillCounts[slotNum]! - 1);
                              }),
                              Text('${_compartmentPillCounts[slotNum]}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.add_circle_outline, size: 18), onPressed: () {
                                if (_compartmentPillCounts[slotNum]! < 10) setState(() => _compartmentPillCounts[slotNum] = _compartmentPillCounts[slotNum]! + 1);
                              }),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                TextField(controller: _msgController, decoration: const InputDecoration(labelText: 'Display Message Modifier', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _syncToFirebase, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('DEPLOY CHANGES TO FIRESTORE DOCUMENT', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardPicker(String label, Widget child) {
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF1F353D).withOpacity(0.4), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.cyanAccent)), const SizedBox(height: 6), child]));
  }

  Widget _buildDropdown(String current, List<String> options, ValueChanged<String?> onChange) {
    return DropdownButtonFormField<String>(value: current, decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 4), border: OutlineInputBorder()), items: options.map((v) => DropdownMenuItem(value: v, child: Center(child: Text(v, style: const TextStyle(fontSize: 13))))).toList(), onChanged: onChange);
  }
}