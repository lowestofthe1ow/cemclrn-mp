import 'dart:io';
import 'package:cemclrn_application/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  // Image File
  File? image;

  // Inference result
  String? resultText;
  double? confidence; 
  bool _isAnalyzing = false; // Loading state

  // Image picker
  final picker = ImagePicker();

  // Pick Image Method
  Future<void> pickImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          image = File(pickedFile.path);
          resultText = null; 
          confidence = null;
        });

        // Run ONLINE inference immediately after picking
        await _runOnlineInference(image!);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  // NEW: Replaced _runOfflineInference with API Call
  Future<void> _runOnlineInference(File imageFile) async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('username');

    if (name == null || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: No username found. Restart app.")),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      resultText = "Analyzing...";
    });

    try {
      // Call the Python API
      final response = await ApiService.verifySignature(
        userName: name,
        imageFile: imageFile,
      );

      if (!mounted) return;

      if (response != null && response.containsKey("Result")) {
        // Success! Update UI with Python's answer
        setState(() {
          resultText = response["Result"]; // "Genuine" or "Forged"
          confidence = response["Avg. distance"] ?? 0.0;
        });
      } else {
        setState(() {
          resultText = "Error";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server returned an error or User not found.")),
        );
      }
    } catch (e) {
      print("Error during inference: $e");
      if (mounted) {
        setState(() {
          resultText = "Connection Failed";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Signature Verifier (Online)",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image display
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: image != null
                  ? Image.file(
                      image!,
                      fit: BoxFit.cover,
                    )
                  : const Center(
                      child: Text(
                        "No image selected",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
            ),

            const SizedBox(height: 20),

            // Display inference result
            if (resultText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _getColorForResult(resultText),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isAnalyzing 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "$resultText\nDistance: ${(confidence ?? 0).toStringAsFixed(4)}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
              ),
            
            const SizedBox(height: 30),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () => pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                ),

                const SizedBox(width: 15),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () => pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper to color-code the result
  Color _getColorForResult(String? result) {
    if (result == "Genuine") return Colors.green;
    if (result == "Forged") return Colors.red;
    if (result == "Analyzing...") return Colors.blue;
    return Colors.grey;
  }
}