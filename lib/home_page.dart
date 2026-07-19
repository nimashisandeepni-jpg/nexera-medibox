import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MediboxMonitorHome extends StatefulWidget {
  const MediboxMonitorHome({super.key});

  @override
  State<MediboxMonitorHome> createState() => _MediboxMonitorHomeState();
}

class _MediboxMonitorHomeState extends State<MediboxMonitorHome> {
  final List<String> _routines = ["morning", "noon", "night"];
  
  Map<String, bool> _routineEnabled = {"morning": true, "noon": false, "night": true};
  final Map<String, String> _routineHours = {"morning": "08", "noon": "12", "night": "20"};
  final Map<String, String> _routineMinutes = {"morning": "00", "noon": "00", "night": "00"};

  final Map<String, Map<int, int>> _routinePillMatrix = {
    "morning": {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0},
    "noon":    {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0},
    "night":   {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0},
  };

  final Map<int, TextEditingController> _nameControllers = Map.fromIterable(
    List.generate(8, (i) => i + 1),
    key: (item) => item,
    value: (item) => TextEditingController(text: ''),
  );
  final _msgController = TextEditingController();

  final List<String> _hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));
  final List<String> _minutes = List.generate(60, (i) => i.toString().padLeft(2, '0'));
  late String _currentFormattedDate;
  
  // Real-time Emergency condition state tracking variable
  bool _isEmergencyActive = false;

  @override
  void initState() {
    super.initState();
    _currentFormattedDate = DateFormat('yyyy - MM - dd (EEEE)').format(DateTime.now());
    _loadStoredConfig();
  }

  void _loadStoredConfig() {
    // Persistent real-time stream listener pipeline (.snapshots())
    FirebaseFirestore.instance
        .collection('medibox')
        .doc('device_01')
        .snapshots()
        .listen((doc) {
      
      // 🔍 Terminal debug confirmation pipeline to track real-time hardware uploads
      debugPrint("🔌 DATA GRABBED! Current Emergency Status in DB: ${doc.data()?['emergency_active']}");

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          // 🔥 FIX: Latch the true state! If it becomes true once, keep it true until dismissed by app.
          if (data['emergency_active'] == true) {
            _isEmergencyActive = true;
          }

          if (data['patient_message'] != null) _msgController.text = data['patient_message'];
          if (data['slot_names'] != null) {
            Map<String, dynamic> names = data['slot_names'];
            names.forEach((key, value) {
              int idx = int.parse(key.replaceAll('slot_', ''));
              _nameControllers[idx]?.text = value.toString();
            });
          }
          
          for (String r in _routines) {
            if (data[r] != null) {
              _routineHours[r] = data[r]['hour'].toString().padLeft(2, '0');
              _routineMinutes[r] = data[r]['minute'].toString().padLeft(2, '0');
              _routineEnabled[r] = data[r]['isEnabled'] ?? true;
              
              for (int slot = 1; slot <= 8; slot++) {
                if (data[r]['slot_$slot'] != null) {
                  _routinePillMatrix[r]![slot] = data[r]['slot_$slot'];
                }
              }
            }
          }
        });
      }
    });
  }

  Future<void> _dismissEmergencyAlert() async {
    try {
      // 1. Instantly drop the visual UI state local variable down to false
      setState(() {
        _isEmergencyActive = false;
      });

      // 2. Sync to the cloud so the physical ESP32 box stops buzzing
      await FirebaseFirestore.instance
          .collection('medibox')
          .doc('device_01')
          .update({'emergency_active': false});
    } catch (e) {
      debugPrint("Error resetting alert: $e");
    }
  }

  Future<void> _syncToFirebase() async {
    final Map<String, dynamic> uploadPayload = {};

    for (String r in _routines) {
      final Map<String, dynamic> routineData = {
        'hour': int.parse(_routineHours[r]!),
        'minute': int.parse(_routineMinutes[r]!),
        'isEnabled': _routineEnabled[r]!,
      };
      _routinePillMatrix[r]!.forEach((slot, count) {
        routineData['slot_$slot'] = count;
      });
      uploadPayload[r] = routineData;
    }

    final Map<String, String> slotNames = {};
    _nameControllers.forEach((key, controller) {
      slotNames['slot_$key'] = controller.text.trim();
    });
    uploadPayload['slot_names'] = slotNames;
    uploadPayload['patient_message'] = _msgController.text.trim();
    uploadPayload['pill_taken'] = false;

    try {
      await FirebaseFirestore.instance
          .collection('medibox')
          .doc('device_01')
          .set(uploadPayload, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚡ Nexera Blueprint Matrix Synced!'), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      appBar: AppBar(
        title: const Text('NEXERA MEDIBOX CONTROL PANEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1, color: Colors.white70)),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CRITICAL EMERGENCY ALERT NOTIFICATION OVERLAY BANNER
            if (_isEmergencyActive) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.shade700,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 26),
                        SizedBox(width: 8),
                        Text(
                          'CRITICAL EMERGENCY ALERT',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'The patient has flipped the emergency switch! Check on them immediately.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _dismissEmergencyAlert,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.redAccent.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('DISMISS & CLEAR ALARM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],

            Center(
              child: Image.asset(
                'assets/nexera.jpg',
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.healing_outlined, color: Colors.tealAccent, size: 22),
                        SizedBox(width: 8),
                        Text('Nexera Medibox Engine Active', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white10),
            
            Text('Date : $_currentFormattedDate', style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 15),
            
            const Text('📅 DAILY TIMELINE ROUTINES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.tealAccent, letterSpacing: 0.5)),
            const SizedBox(height: 8),

            Column(children: _routines.map((r) => _buildBlueprintRoutineCard(r)).toList()),
            
            const SizedBox(height: 15),
            const Text('✏️ NAME EXTRACTED TABLETS ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54)),
            const SizedBox(height: 10),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 8,
                itemBuilder: (context, index) {
                  int slotNum = index + 1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 55,
                          child: Text('Slot $slotNum :', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              controller: _nameControllers[slotNum],
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter Tablet Name (e.g. Panadol)',
                                hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                filled: true,
                                fillColor: const Color(0xFF0F172A), 
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 15),
            const Text('💬 MESSAGE FOR PATIENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54)),
            const SizedBox(height: 8),
            TextField(
              controller: _msgController,
              maxLength: 60,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Drink water with this dose & sleep well!',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                counterStyle: const TextStyle(color: Colors.white24),
              ),
            ),
            
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _syncToFirebase, 
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent, 
                foregroundColor: const Color(0xFF0F172A), 
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ), 
              child: const Text('CONFIRM!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlueprintRoutineCard(String routine) {
    bool isEnabled = _routineEnabled[routine] ?? false;
    return Card(
      color: isEnabled ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withOpacity(0.4),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Switch(
                  value: isEnabled,
                  activeColor: Colors.tealAccent,
                  onChanged: (val) => setState(() => _routineEnabled[routine] = val),
                ),
                const SizedBox(width: 4),
                Text(
                  routine.toUpperCase(), 
                  style: TextStyle(fontWeight: FontWeight.bold, color: isEnabled ? Colors.white : Colors.white38, fontSize: 13)
                ),
              ],
            ),
            
            if (isEnabled) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  const Text('Alarm Time: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70, 
                    child: _buildInlineDropdown(_routineHours[routine]!, _hours, (v) => setState(() => _routineHours[routine] = v!)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6), 
                    child: Text(":", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(
                    width: 70, 
                    child: _buildInlineDropdown(_routineMinutes[routine]!, _minutes, (v) => setState(() => _routineMinutes[routine] = v!)),
                  ),
                ],
              ),
            ],
            
            const Divider(color: Colors.white10, height: 20),
            
            IgnorePointer(
              ignoring: !isEnabled,
              child: Opacity(
                opacity: isEnabled ? 1.0 : 0.25,
                child: Center(
                  child: Wrap(
                    spacing: 6.0,
                    runSpacing: 8.0,
                    alignment: WrapAlignment.center,
                    children: List.generate(8, (index) {
                      int slotNum = index + 1;
                      int currentCount = _routinePillMatrix[routine]![slotNum] ?? 0;
                      return Container(
                        width: 56,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: currentCount > 0 ? Colors.tealAccent.withOpacity(0.5) : Colors.white10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('S-$slotNum', style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  int nextCount = (currentCount + 1) > 3 ? 0 : (currentCount + 1);
                                  _routinePillMatrix[routine]![slotNum] = nextCount;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: currentCount > 0 ? Colors.tealAccent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4)
                                ),
                                child: Text(
                                  '$currentCount',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: currentCount > 0 ? const Color(0xFF0F172A) : Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInlineDropdown(String current, List<String> options, ValueChanged<String?> onChange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent, size: 16),
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(fontSize: 13, color: Colors.white),
          items: options.map((v) => DropdownMenuItem(
            value: v, 
            child: Text(v, style: const TextStyle(fontSize: 13, color: Colors.white)),
          )).toList(),
          onChanged: onChange,
        ),
      ),
    );
  }
}