import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'camera_page.dart'; 

/**
 * Welcome Page:
 * - Prompts the user to enter their name.
 * - Saves the name locally to SharedPreferences.
 * - Navigates to CameraPage immediately (Offline mode).
 */

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final TextEditingController _nameController = TextEditingController();

  // Save name locally to SharedPreferences and continue
  Future<void> _saveNameAndContinue() async {
    final name = _nameController.text.trim();
    
    // Basic validation to ensure name isn't empty
    if (name.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    // Save name locally
    await prefs.setString('username', name);

    if (!mounted) return;

    // Navigate to Camera Page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CameraPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Welcome!",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Input field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Enter your name",
                border: const OutlineInputBorder(),
                // Arrow button
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    if (_nameController.text.trim().isNotEmpty) {
                      _saveNameAndContinue();
                    }
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
