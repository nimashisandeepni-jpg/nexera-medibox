import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Updated package to target RTDB
import 'login_page.dart';

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

  // Tracks matrix allocation data model locally
  final Map<int, int> _compartmentPillCounts = {
    1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0
  };

  final List<String> _hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));
  final List<String> _minutesSeconds = List.generate(60, (i) => i.toString().padLeft(2, '0'));
  final List<String> _days = List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
  final List<String> _months = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
  final List<String> _years = List.generate(6, (i) => (2026 + i).toString());

  // RTDB Instance Pointer Reference
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Future<void> syncMultiPillSchedule() async {
    // Compile parameters into integers to match your ESP32's 'result.intValue' streams perfectly
    int dayInt = int.parse(_selectedDay);
    int hourInt = int.parse(_selectedHour);
    int minuteInt = int.parse(_selectedMinute);

    try {
      // Deploys updates straight into your exact hardware node listener point
      await _dbRef.child('AlarmSettings').update({
        'day': dayInt,
        'hour': hourInt,
        'minute': minuteInt,
        'isEnabled': true, // Flips to TRUE so your 'myAlarm.isEnabled == true' logic registers
        'extra_message': _msgController.text.isEmpty ? "Take your medicine" : _msgController.text,
        'pill_taken': false,
      });

      _msgController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚡ RTDB Stream Packet Synced Instantly!'), backgroundColor: Colors.green),
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
        title: const Text('NEXERA MULTI-PILL DISPENSER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1)),
        backgroundColor: const Color(0xFF203A43),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => NexeraLoginPage()));
            },
          )
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        // Connects your live UI elements to display RTDB streaming modifications
        stream: FirebaseDatabase.instance.ref().child('AlarmSettings').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final Map<dynamic, dynamic>? data = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
          
          // Render safe fallback default constants if data node is initialized clean
          final int liveHour = data?['hour'] ?? 0;
          final int liveMinute = data?['minute'] ?? 0;
          final int liveDay = data?['day'] ?? 0;
          final String liveMsg = data?['extra_message'] ?? 'None';
          final bool pillTaken = data?['pill_taken'] ?? true;

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
                          Icon(Icons.crisis_alert_rounded, color: Colors.redAccent, size: 28),
                          SizedBox(width: 12),
                          Expanded(child: Text('ALERT: Patient hasn\'t extracted the multi-pill dose from the unit yet.', style: TextStyle(color: Colors.white70, fontSize: 12))),
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
                      Text('LIVE RTDB HARDWARE MONITOR: Day $liveDay @ $liveHour:${liveMinute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 4),
                      Text('Note: "$liveMsg"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

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

                TextField(
                  controller: _msgController,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Display Message (e.g. Eat well, Drink water)', prefixIcon: Icon(Icons.chat_outlined), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: const Color(0xFF0F2027), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: syncMultiPillSchedule,
                  icon: const Icon(Icons.cloud_done_rounded),
                  label: const Text('DEPLOY STREAM PACKET TO DEVICE', style: TextStyle(fontWeight: FontWeight.bold)),
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