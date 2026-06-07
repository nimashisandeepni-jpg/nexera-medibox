import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart'; // Your main Medibox dashboard page

class NexeraLoginPage extends StatefulWidget {
  @override
  _NexeraLoginPageState createState() => _NexeraLoginPageState();
}

class _NexeraLoginPageState extends State<NexeraLoginPage> {
  // Hardcoded master credentials for the entire team
  final String masterEmail = "nexera.medibox@gmail.com";
  final String masterPassword = "nexeraproject2026";

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    String inputEmail = _emailController.text.trim();
    String inputPassword = _passwordController.text.trim();

    // 1. Strict verification checkpoint
    if (inputEmail != masterEmail || inputPassword != masterPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: Unauthorized Nexera Team Credentials!")),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // 2. Authenticate against your live Firebase Cloud engine
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: inputEmail, password: inputPassword);

      if (userCredential.user != null) {
        // Success! Route straight to the control panel
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MediboxMonitorHome()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Firebase Connection Failed: ${e.toString()}")),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212), // Sleek dark mode theme
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "NEXERA MEDIBOX",
                style: TextStyle(color: Colors.blueAccent, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text("Control Centre Authentication", style: TextStyle(color: Colors.grey)),
              SizedBox(height: 32),
              TextField(
                controller: _emailController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Team Email ID",
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Security Password",
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                ),
              ),
              SizedBox(height: 32),
              _isLoading 
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: Size(200, 45)),
                    child: Text("Login to System"),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}