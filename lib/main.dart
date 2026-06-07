import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const NexeraMediboxApp());
}

class NexeraMediboxApp extends StatelessWidget {
  const NexeraMediboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexera Medibox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.cyanAccent,
        useMaterial3: true,
      ),
      home: const NexeraLoginPage(),
    );
  }
}