import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class NexeraLoginPage extends StatefulWidget {
  const NexeraLoginPage({super.key});

  @override
  State<NexeraLoginPage> createState() => _NexeraLoginPageState();
}

class _NexeraLoginPageState extends State<NexeraLoginPage> {
  // ── Hardcoded master credentials ──────────────────────────────────────────
  static const String _masterEmail    = "nexera.medibox@gmail.com";
  static const String _masterPassword = "nexeraproject2026";

  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading       = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final inputEmail    = _emailController.text.trim();
    final inputPassword = _passwordController.text.trim();

    // 1. Local credential gate
    if (inputEmail != _masterEmail || inputPassword != _masterPassword) {
      _showSnack("Unauthorized credentials. Try again.", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Firebase Auth sign-in
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    inputEmail,
        password: inputPassword,
      );

      if (cred.user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MediboxMonitorHome()),
        );
      }
    } on Exception catch (e) {
      _showSnack("Firebase error: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo / Icon ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Color(0xFF00E5FF), Color(0xFF0A1628)]),
                  boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.4), blurRadius: 30)],
                ),
                child: const Icon(Icons.medical_services_rounded, size: 52, color: Colors.white),
              ),
              const SizedBox(height: 24),

              // ── Title ───────────────────────────────────────────────────
              const Text(
                "NEXERA MEDIBOX",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Control Centre Authentication",
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 40),

              // ── Email field ─────────────────────────────────────────────
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Team Email ID", Icons.email_outlined),
              ),
              const SizedBox(height: 16),

              // ── Password field ──────────────────────────────────────────
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  "Security Password",
                  Icons.lock_outline_rounded,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // ── Login button ────────────────────────────────────────────
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.cyanAccent)
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleLogin,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text(
                          "LOGIN TO SYSTEM",
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: const Color(0xFF0A1628),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.cyanAccent),
      filled: true,
      fillColor: const Color(0xFF1A2E4A),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2A4A6A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
      ),
    );
  }
}