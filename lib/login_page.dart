import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import local storage SDK
import 'home_page.dart';

class NexeraLoginPage extends StatefulWidget {
  const NexeraLoginPage({super.key});

  @override
  State<NexeraLoginPage> createState() => _NexeraLoginPageState();
}

class _NexeraLoginPageState extends State<NexeraLoginPage> {
  final String masterEmail = "nexera.medibox@gmail.com";
  final String masterPassword = "nexeraproject2026";

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false; // Tracking variable for the checkbox state

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Auto-check local storage on startup
  }

  // Fetch credentials from Shared Preferences if they exist
  void _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';
      final rememberCheck = prefs.getBool('remember_me') ?? false;

      if (rememberCheck) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
          _rememberMe = rememberCheck;
        });
      }
    } catch (e) {
      debugPrint("Local storage read error: $e");
    }
  }

  // Save or clear credentials depending on checkbox state
  void _saveCredentialsState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setString('saved_password', _passwordController.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      // Clear storage matrix if unchecked
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  void _handleLogin() async {
    String inputEmail = _emailController.text.trim();
    String inputPassword = _passwordController.text.trim();

    if (inputEmail != masterEmail || inputPassword != masterPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Unauthorized Nexera Team Credentials!")),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: inputEmail, password: inputPassword);

      if (userCredential.user != null && mounted) {
        _saveCredentialsState(); // Handle local cache pipeline before moving screens

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MediboxMonitorHome()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Firebase Authentication Failed: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("NEXERA MEDIBOX", style: TextStyle(color: Colors.blueAccent, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Control Centre Authentication", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Team Email ID", 
                  labelStyle: TextStyle(color: Colors.white60),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Security Password", 
                  labelStyle: TextStyle(color: Colors.white60),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                ),
              ),
              const SizedBox(height: 12),
              
              // 🛠️ REMEMBER ME CHECKBOX WIDGET
              Theme(
                data: ThemeData(unselectedWidgetColor: Colors.white60),
                child: CheckboxListTile(
                  title: const Text("Remember Login Info", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  value: _rememberMe,
                  activeColor: Colors.blueAccent,
                  checkColor: Colors.white,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (bool? value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              
              _isLoading 
                ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent))
                : ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text("Login to System", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}