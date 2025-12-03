import 'dart:io';
import 'package:cemclrn_application/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'camera_page.dart';

/**
 * Welcome Page (Enhanced):
 * - Prompts user for name.
 * - Allows Registering a new user (with image).
 * - Allows Updating an existing user (adding signatures).
 * - Navigates to CameraPage for verification.
 */

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final TextEditingController _nameController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;

  // 1. Pick Image Logic
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // 2. Register User (API Call)
  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty || _selectedImage == null) {
      _showSnackBar("Name and Image required to Register", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    // Send as a list (since your API expects 'files')
    await ApiService.registerUser(
      userName: _nameController.text.trim(),
      imageFiles: [_selectedImage!], 
    );

    setState(() => _isLoading = false);
    _showSnackBar("Register Request Sent! Check Python Console.", Colors.blue);
  }

  // 3. Update Signature (API Call)
  Future<void> _handleUpdate() async {
    if (_nameController.text.isEmpty || _selectedImage == null) {
      _showSnackBar("Name and Image required to Update", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    await ApiService.uploadSignature(
      userName: _nameController.text.trim(),
      imageFile: _selectedImage!,
    );

    setState(() => _isLoading = false);
    _showSnackBar("Update Request Sent! Check Python Console.", Colors.green);
  }

  // 4. Save Name and Go to Camera (Existing Logic)
  Future<void> _saveNameAndContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar("Please enter your name to continue", Colors.red);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);

    if (!mounted) return;

    // Navigate to Camera Page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CameraPage()),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("User Setup"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Welcome!",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Name Input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Enter your name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),

            // Image Picker
            const Text("Select a signature for Registration/Update:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[100],
                ),
                child: _selectedImage != null
                    ? Image.file(_selectedImage!, fit: BoxFit.contain)
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                          Text("Tap to pick image"),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Buttons
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleRegister,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      child: const Text("Register User", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleUpdate,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("Update Sig", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),

            // Continue Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveNameAndContinue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text("CONTINUE TO DETECTOR"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}