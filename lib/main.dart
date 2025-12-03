import 'package:cemclrn_application/services/api_service.dart';
import 'package:http/http.dart' as http;

import 'pages/welcome_page.dart';
import 'package:flutter/material.dart';
import 'pages/camera_page.dart';

  void main() {
    runApp(const MyApp());
  }

  class MyApp extends StatelessWidget {
    const MyApp({super.key});

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const CheckStart(),
      );
    }
  }

  class CheckStart extends StatefulWidget {
  const CheckStart({super.key});

  @override
  State<CheckStart> createState() => _CheckStartState();
}

class _CheckStartState extends State<CheckStart> {
  @override
  void initState() {
    super.initState();
    _decideInitialScreen();
  }

  Future<void> _decideInitialScreen() async {
    bool isServerOnline = false;

    try {
      // Try to ping the server
      final uri = Uri.parse('${ApiService.baseUrl}/docs');
      final response = await http.get(uri).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        isServerOnline = true;
      }
    } catch (e) {
      print("Server unreachable ($e)");
      isServerOnline = false;
    }

    if (!mounted) return;

    // 2. Navigate based on status
    if (isServerOnline) {
      print("Server Online");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
      );
    } else {
      print("Server Offline");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CameraPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 20),
            Text("Checking Connection...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}