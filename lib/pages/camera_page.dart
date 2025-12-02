import 'dart:io';
import 'dart:typed_data';
import 'package:cemclrn_application/services/signature_verifier_service.dart';
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

  // Image picker
  final picker = ImagePicker();

  // 1. Instantiate service
  final SignatureVerifierService _verifier = SignatureVerifierService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _verifier.loadModel();
      print("Model loaded!");
    });
  }

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

        // Run local inference after picking
        await _runOfflineInference(image!);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  // CORE LOGIC: This is where the verification happens
  Future<void> _runOfflineInference(File imageFile) async {
    final prefs = await SharedPreferences.getInstance();
    // Use this 'name' later to find the correct folder of reference signatures
    final name = prefs.getString('username') ?? "TestUser";

    setState(() {
      resultText = "Processing...";
    });

    try {
      // ---------------------------------------------------------
      // PYTORCH INTEGRATION POINT
      // ---------------------------------------------------------
      
      // 2. Get bytes from your captured questioned image
      Uint8List questionedBytes = await imageFile.readAsBytes();

      // 3. Get bytes from your reference image
      // TODO: FOR PRODUCTION -> Load the real reference signatures from ApplicationDocumentsDirectory
      // File referenceFile = File('/data/user/0/com.yourapp/app_flutter/Signatures/$name/sig1.png');
      // Uint8List referenceBytes = await referenceFile.readAsBytes();

      // FOR TESTING NOW -> We compare the image against ITSELF.
      // This should guarantee a "Genuine" result (Distance 0.0) to prove the code works.
      Uint8List referenceBytes = questionedBytes; 

      // 4. Run verification
      // Note: verify() returns a Map with 'isGenuine', 'distance', etc.
      var result = await _verifier.verify(questionedBytes, referenceBytes);

      bool isGenuine = result['isGenuine'];
      double dist = result['distance'];

      // Debug prints for your console
      if (isGenuine) {
        print("GENUINE! Distance: $dist");
      } else {
        print("FORGED! Distance: $dist");
      }

      if (!mounted) return;

      setState(() {
        resultText = isGenuine ? "Genuine" : "Forged";
        confidence = dist; 
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Result: $resultText, Distance: ${dist.toStringAsFixed(4)}"),
          backgroundColor: isGenuine ? Colors.green : Colors.red,
        ),
      );

    } catch (e) {
      print("Error during inference: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Inference failed: $e")),
        );
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
          "Forged Signature Detector",
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
            if (resultText != null && resultText != "Processing...")
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: resultText == "Genuine" ? Colors.green[300] : Colors.red[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$resultText\nDistance: ${(confidence ?? 0).toStringAsFixed(4)}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            
            // Loading Indicator
            if (resultText == "Processing...")
              const CircularProgressIndicator(),

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
}
