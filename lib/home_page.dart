import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_page.dart';

class MediboxMonitorHome extends StatefulWidget {
  const MediboxMonitorHome({super.key});

  @override
  State<MediboxMonitorHome> createState() => _MediboxMonitorHomeState();
}

class _MediboxMonitorHomeState extends State<MediboxMonitorHome> {
  // ── Firebase reference ───────────────────────────────────────────────────
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // ── Message controller ───────────────────────────────────────────────────
  final TextEditingController _msgController = TextEditingController();

  // ── Alarm time/date dropdowns ─────────────────────────────────────────────
  String _selectedHour   = "08";
  String _selectedMinute = "30";
  String _selectedSecond = "00";
  String _selectedDay    = "06";
  String _selectedMonth  = "06";
  String _selectedYear   = "2026";

  // ── Pill counts per compartment (1–8) ────────────────────────────────────
  // These represent how many pills the patient should take from each slot
  final Map<int, int> _compartmentPillCounts = {
    1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0,
  };

  // ── Dropdown option lists ────────────────────────────────────────────────
  final List<String> _hours          = List.generate(24, (i) => i.toString().padLeft(2, '0'));
  final List<String> _minutesSeconds = List.generate(60, (i) => i.toString().padLeft(2, '0'));
  final List<String> _days           = List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
  final List<String> _months         = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
  final List<String> _years          = List.generate(6,  (i) => (2026 + i).toString());

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  // ── Sync alarm + pill matrix to Firebase ─────────────────────────────────
  // This writes to /AlarmSettings (read by ESP32 stream) AND
  // /PillMatrix (for compartment counts)
  Future<void> _syncToFirebase() async {
    final int hourInt   = int.parse(_selectedHour);
    final int minuteInt = int.parse(_selectedMinute);
    final int dayInt    = int.parse(_selectedDay);

    // Build pill matrix map with String keys (Firebase requires String keys)
    final Map<String, dynamic> pillMap = {};
    for (int slot = 1; slot <= 8; slot++) {
      pillMap['slot_$slot'] = _compartmentPillCounts[slot] ?? 0;
    }

    try {
      // ── Write AlarmSettings (ESP32 stream listens here) ─────────────────
      await _dbRef.child('AlarmSettings').update({
        'day':           dayInt,
        'hour':          hourInt,
        'minute':        minuteInt,
        'isEnabled':     true,     // <-- CRITICAL: ESP32 checks this == true
        'extra_message': _msgController.text.isEmpty
            ? "Take your medicine"
            : _msgController.text,
        'pill_taken':    false,    // Reset on every new schedule deploy
      });

      // ── Write PillMatrix separately ──────────────────────────────────────
      await _dbRef.child('PillMatrix').update(pillMap);

      _msgController.clear();
      _showSnack('✅ Schedule deployed to device!', Colors.green);
    } catch (e) {
      _showSnack('❌ Error: $e', Colors.redAccent);
    }
  }

  // ── Mark pill as taken manually from app ─────────────────────────────────
  Future<void> _markPillTaken() async {
    try {
      await _dbRef.child('AlarmSettings').update({'pill_taken': true});
      _showSnack('💊 Marked as taken!', Colors.green);
    } catch (e) {
      _showSnack('Error: $e', Colors.redAccent);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const NexeraLoginPage()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text(
          'NEXERA MEDIBOX',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 2.5,
            color: Colors.cyanAccent,
          ),
        ),
        backgroundColor: const Color(0xFF0F1E35),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),

      // ── Live stream from Firebase ─────────────────────────────────────────
      body: StreamBuilder<DatabaseEvent>(
        stream: _dbRef.child('AlarmSettings').onValue,
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Stream error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }

          // Parse live data safely
          final raw = snapshot.data?.snapshot.value;
          final data = raw is Map ? Map<String, dynamic>.from(raw as Map) : <String, dynamic>{};

          final int    liveHour    = (data['hour']    as int?)    ?? 0;
          final int    liveMinute  = (data['minute']  as int?)    ?? 0;
          final int    liveDay     = (data['day']      as int?)    ?? 0;
          final String liveMsg     = (data['extra_message'] as String?) ?? 'None';
          final bool   pillTaken   = (data['pill_taken']    as bool?)   ?? true;
          final bool   isEnabled   = (data['isEnabled']     as bool?)   ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── 1. ALERT BANNER (pill not taken) ────────────────────────
                if (!pillTaken) ...[
                  _alertBanner(),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _markPillTaken,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('MARK AS TAKEN MANUALLY'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── 2. LIVE STATUS CARD ──────────────────────────────────────
                _liveStatusCard(liveDay, liveHour, liveMinute, liveMsg, isEnabled),
                const SizedBox(height: 20),

                // ── 3. SET ALARM TIME ────────────────────────────────────────
                _sectionLabel('⏱  SET ALARM TIME (HH : MM : SS)'),
                const SizedBox(height: 8),
                _buildCardPicker(
                  Row(children: [
                    Expanded(child: _buildDropdown(_selectedHour,   _hours,          (v) => setState(() => _selectedHour   = v!))),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text(':', style: TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold))),
                    Expanded(child: _buildDropdown(_selectedMinute, _minutesSeconds, (v) => setState(() => _selectedMinute = v!))),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text(':', style: TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold))),
                    Expanded(child: _buildDropdown(_selectedSecond, _minutesSeconds, (v) => setState(() => _selectedSecond = v!))),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── 4. SET DATE ──────────────────────────────────────────────
                _sectionLabel('📆  SET DATE (DD / MM / YYYY)'),
                const SizedBox(height: 8),
                _buildCardPicker(
                  Row(children: [
                    Expanded(child: _buildDropdown(_selectedDay,   _days,   (v) => setState(() => _selectedDay   = v!))),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('/', style: TextStyle(color: Colors.white38))),
                    Expanded(child: _buildDropdown(_selectedMonth, _months, (v) => setState(() => _selectedMonth = v!))),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('/', style: TextStyle(color: Colors.white38))),
                    Expanded(child: _buildDropdown(_selectedYear,  _years,  (v) => setState(() => _selectedYear  = v!))),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── 5. PILL MATRIX (8 compartments) ─────────────────────────
                _sectionLabel('💊  PILL MATRIX — SET DOSES PER COMPARTMENT'),
                const SizedBox(height: 4),
                const Text(
                  'Set how many pills the patient should take from each slot. This syncs to Firebase.',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(height: 10),
                _buildPillMatrix(),
                const SizedBox(height: 20),

                // ── 6. DISPLAY MESSAGE ──────────────────────────────────────
                _sectionLabel('💬  DISPLAY MESSAGE'),
                const SizedBox(height: 8),
                TextField(
                  controller: _msgController,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Eat before taking, Drink water...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.cyanAccent),
                    filled: true,
                    fillColor: const Color(0xFF1A2E4A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.cyanAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── 7. DEPLOY BUTTON ─────────────────────────────────────────
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: const Color(0xFF0A1628),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 8,
                    shadowColor: Colors.cyanAccent.withOpacity(0.5),
                  ),
                  onPressed: _syncToFirebase,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 22),
                  label: const Text(
                    'DEPLOY SCHEDULE TO DEVICE',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _alertBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.crisis_alert_rounded, color: Colors.redAccent, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '⚠  ALERT: Pill dose not yet extracted from the unit!',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveStatusCard(int day, int hour, int minute, String msg, bool enabled) {
    final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors_rounded, color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 6),
              const Text('LIVE RTDB MONITOR', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: enabled ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: enabled ? Colors.greenAccent : Colors.redAccent),
                ),
                child: Text(
                  enabled ? 'ACTIVE' : 'DISABLED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: enabled ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 16),
          Text(
            'Day $day  ·  $timeStr',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '📝  "$msg"',
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildPillMatrix() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:  2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        final slotNum = index + 1;
        final count   = _compartmentPillCounts[slotNum] ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: count > 0
                ? Colors.cyanAccent.withOpacity(0.07)
                : const Color(0xFF1A2E4A).withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: count > 0 ? Colors.cyanAccent.withOpacity(0.4) : Colors.white10,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SLOT $slotNum',
                    style: const TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1),
                  ),
                  Text(
                    count == 0 ? 'Empty' : '$count pill${count > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: count > 0 ? Colors.cyanAccent : Colors.white30,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Decrement
                  _pillButton(
                    icon: Icons.remove,
                    onTap: count > 0
                        ? () => setState(() => _compartmentPillCounts[slotNum] = count - 1)
                        : null,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  // Increment
                  _pillButton(
                    icon: Icons.add,
                    onTap: count < 10
                        ? () => setState(() => _compartmentPillCounts[slotNum] = count + 1)
                        : null,
                    color: Colors.greenAccent,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pillButton({required IconData icon, VoidCallback? onTap, required Color color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.15) : Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: onTap != null ? color.withOpacity(0.5) : Colors.white10),
        ),
        child: Icon(icon, size: 16, color: onTap != null ? color : Colors.white24),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.white54,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildCardPicker(Widget content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: content,
    );
  }

  Widget _buildDropdown(String current, List<String> options, ValueChanged<String?> onChange) {
    return DropdownButtonFormField<String>(
      value: current,
      isExpanded: true,
      dropdownColor: const Color(0xFF1A2E4A),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        filled: true,
        fillColor: const Color(0xFF0F1E35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.cyanAccent),
        ),
      ),
      items: options
          .map((v) => DropdownMenuItem(
                value: v,
                child: Center(child: Text(v)),
              ))
          .toList(),
      onChanged: onChange,
    );
  }
}