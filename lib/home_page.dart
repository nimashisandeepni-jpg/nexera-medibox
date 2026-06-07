import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexera Medibox Multi-Dispenser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F2027), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const MediboxMonitorHome(),
    );
  }
}

class MediboxMonitorHome extends StatefulWidget {
  const MediboxMonitorHome({super.key});

  @override
  State<MediboxMonitorHome> createState() => _MediboxMonitorHomeState();
}

class _MediboxMonitorHomeState extends State<MediboxMonitorHome> {
  final _msgController = TextEditingController();

  // Time & Date Dropdown States
  String _selectedHour = "08";
  String _selectedMinute = "30";
  String _selectedSecond = "00";
  String _selectedDay = "06";
  String _selectedMonth = "06";
  String _selectedYear = "2026";

  // --- MULTI-COMPARTMENT PILL COUNT STATE ---
  // Tracks how many pills are assigned to each of the 8 compartments
  final Map<int, int> _compartmentPillCounts = {
    1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0
  };

  final List<String> _hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));
  final List<String> _minutesSeconds = List.generate(60, (i) => i.toString().padLeft(2, '0'));
  final List<String> _days = List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
  final List<String> _months = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
  final List<String> _years = List.generate(6, (i) => (2026 + i).toString());

  Future<void> syncMultiPillSchedule() async {
    String formattedTime = "$_selectedHour:$_selectedMinute:$_selectedSecond";
    String formattedDate = "$_selectedDay/$_selectedMonth/$_selectedYear";

    // Convert our map into a format Firestore strings easily (e.g., {"slot_1": 2, "slot_2": 0})
    Map<String, int> dbCompartmentMap = {};
    _compartmentPillCounts.forEach((slotNum, pillCount) {
      dbCompartmentMap['slot_$slotNum'] = pillCount;
    });

    try {
      await FirebaseFirestore.instance
          .collection('medibox')
          .doc('device_01')
          .update({
        'alarm_time': formattedTime,
        'alarm_date': formattedDate,
        'compartments': dbCompartmentMap, // Uploads the whole matrix together!
        'extra_message': _msgController.text.isEmpty ? "Take your medicine" : _msgController.text,
        'pill_taken': false,
      });

      _msgController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚡ Multi-Pill Manifest Synced Worldwide!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('NEXERA MULTI-PILL DISPENSER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        backgroundColor: const Color(0xFF203A43),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('medibox').doc('device_01').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data == null) return const Center(child: Text('Device baseline profile missing.'));

          final String liveTime = data['alarm_time'] ?? '00:00:00';
          final String liveDate = data['alarm_date'] ?? '00/00/0000';
          final String liveMsg = data['extra_message'] ?? 'None';
          final bool pillTaken = data['pill_taken'] ?? true;
          
          // Read live compartment payload configurations safely
          final Map<String, dynamic> liveSlots = data['compartments'] ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. COMPLIANCE ALERT BANNER
                if (!pillTaken)
                  Card(
                    color: Colors.redAccent.withOpacity(0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent)),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.crisis_alert_rounded, color: Colors.redAccent, size: 28),
                          SizedBox(width: 12),
                          Expanded(child: Text('ALERT: Patient hasn\'t extracted the multi-pill dose from the unit yet.', style: TextStyle(color: Colors.white70, fontSize: 12))),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),

                // 2. ACTIVE LIVE MANIFEST MONITOR PANEL
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1F353D), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LIVE MONITOR: $liveDate @ $liveTime', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                      const Divider(color: Colors.white10),
                      const Text('🚨 Active Pill Load Checklist:', style: TextStyle(fontSize: 12, color: Colors.white60)),
                      const SizedBox(height: 6),
                      // Display all slots that contain pills (> 0)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: List.generate(8, (i) {
                          int slotNum = i + 1;
                          int count = liveSlots['slot_$slotNum'] ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return Chip(
                            backgroundColor: Colors.amberAccent.withOpacity(0.1),
                            side: const BorderSide(color: Colors.amberAccent),
                            label: Text('Slot $slotNum: $count Pills', style: const TextStyle(fontSize: 11, color: Colors.amberAccent)),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text('Note: "$liveMsg"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. TIME & DATE SCHEDULING ROW PICKERS
                Row(
                  children: [
                    Expanded(
                      child: _buildCardPicker('⏱️ Time (HH:MM:SS)', Row(
                        children: [
                          Expanded(child: _buildDropdown(_selectedHour, _hours, (v) => setState(() => _selectedHour = v!))),
                          Expanded(child: _buildDropdown(_selectedMinute, _minutesSeconds, (v) => setState(() => _selectedMinute = v!))),
                          Expanded(child: _buildDropdown(_selectedSecond, _minutesSeconds, (v) => setState(() => _selectedSecond = v!))),
                        ],
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildCardPicker('📆 Date (DD/MM/YYYY)', Row(
                  children: [
                    Expanded(child: _buildDropdown(_selectedDay, _days, (v) => setState(() => _selectedDay = v!))),
                    Expanded(child: _buildDropdown(_selectedMonth, _months, (v) => setState(() => _selectedMonth = v!))),
                    Expanded(child: _buildDropdown(_selectedYear, _years, (v) => setState(() => _selectedYear = v!))),
                  ],
                )),
                const SizedBox(height: 16),

                // 4. THE 8-COMPARTMENT MATRIX SELECTION ENGINE
                const Text('⚙️ CONFIG COMPARTMENT PILL MATRIX (SLOTS 1 - 8)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54)),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.3,
                  ),
                  itemCount: 8,
                  itemBuilder: (context, index) {
                    int slotNum = index + 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF1F353D).withOpacity(0.6), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Compartment Slot $slotNum', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _compartmentPillCounts[slotNum],
                              isDense: true,
                              items: List.generate(6, (i) => i).map((int val) {
                                return DropdownMenuItem<int>(value: val, child: Text(val == 0 ? 'Empty (0)' : '$val Pills', style: TextStyle(fontSize: 13, color: val > 0 ? Colors.greenAccent : Colors.white60)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _compartmentPillCounts[slotNum] = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 5. INSTRUCTION NOTES FIELD
                TextField(
                  controller: _msgController,
                  decoration: const InputDecoration(labelText: 'Display Message (e.g. Eat well, Drink water)', prefixIcon: Icon(Icons.chat_outlined), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),

                // TRANSMISSION CONTROL SYNC
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: const Color(0xFF0F2027), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: syncMultiPillSchedule,
                  icon: const Icon(Icons.cloud_done_rounded),
                  label: const Text('DEPLOY MATRIX SELECTION TO DEVICE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardPicker(String label, Widget rowSelectors) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF1F353D).withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.cyanAccent)), const SizedBox(height: 6), rowSelectors]),
    );
  }

  Widget _buildDropdown(String current, List<String> options, ValueChanged<String?> onChange) {
    return DropdownButtonFormField<String>(value: current, decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 4), border: OutlineInputBorder()), items: options.map((v) => DropdownMenuItem(value: v, child: Center(child: Text(v, style: const TextStyle(fontSize: 13))))).toList(), onChanged: onChange);
  }
}