import 'dart:io';
import 'dart:typed_data';
import 'package:cemclrn_application/services/api_service.dart';
import 'package:cemclrn_application/services/signature_verifier_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/**
 * Camera Page
 * - Online Inference through web server
 * - Offline Inference through .ptl
 */

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  File? _questionedImage;
  File? _referenceImage;

  String? resultText;
  double? confidence;
  bool _isAnalyzing = false;
  
  bool _isOfflineMode = false; 

  final picker = ImagePicker();
  final SignatureVerifierService _offlineVerifier = SignatureVerifierService();

  @override
  void initState() {
    super.initState();
    _offlineVerifier.loadModel();
    _checkServerStatus();
  }

  Future<void> _checkServerStatus() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/docs');
      final response = await http.get(uri).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _isOfflineMode = false;
          });
        }
      } else {
        _switchToOffline("Server returned ${response.statusCode}");
      }
    } catch (e) {
      _switchToOffline("Server unreachable");
    }
  }

  void _switchToOffline(String reason) {
    if (!mounted) return;
    setState(() {
      _isOfflineMode = true;
    });
    _showSnack("Offline Mode Active: $reason", Colors.blueGrey);
  }

  // 1. Pick the main image
  Future<void> pickQuestionedImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _questionedImage = File(pickedFile.path);
          resultText = null;
          confidence = null;
        });
        
        if (_isOfflineMode) {
          // If already offline, just wait for reference image
          if (_referenceImage != null) _runOfflineInference();
        } else {
          // If online, try the API
          await _runRobustInference(_questionedImage!);
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> pickReferenceImage() async {
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _referenceImage = File(pickedFile.path);
        });
        
        // If we have both, run check immediately
        if (_questionedImage != null) {
          await _runOfflineInference();
        }
      }
    } catch (e) {
      debugPrint("Error picking reference: $e");
    }
  }

  // Try online, fallback to offline if can not connect to server
  Future<void> _runRobustInference(File imageFile) async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('username');

    if (name == null || name.isEmpty) {
      _showSnack("Error: No username found.", Colors.red);
      return;
    }

    setState(() {
      _isAnalyzing = true;
      resultText = "Connecting...";
    });

    try {
      // Try API with 4s timeout
      final response = await ApiService.verifySignature(
        userName: name,
        imageFile: imageFile,
      ).timeout(const Duration(seconds: 4)); 

      if (response != null && response.containsKey("Result")) {
         setState(() {
           resultText = response["Result"];
           confidence = response["Avg. distance"] ?? 0.0;
           _isAnalyzing = false;
           _isOfflineMode = false; 
         });
         return;
      }
    } catch (e) {
      print("Connection failed. Activating Offline Mode.");
    }

    // Fallback to Offline
    setState(() {
      _isAnalyzing = false;
      _isOfflineMode = true; 
      resultText = null;    
    });
  }

  // [Offline] 
  Future<void> _runOfflineInference() async {
    if (_questionedImage == null || _referenceImage == null) return;

    setState(() {
      _isAnalyzing = true;
      resultText = "Comparing Images...";
    });

    // Read bytes from images
    Uint8List qBytes = await _questionedImage!.readAsBytes();
    Uint8List rBytes = await _referenceImage!.readAsBytes();

    // Run PTL Model
    var result = await _offlineVerifier.verify(qBytes, rBytes);

    if (!mounted) return;

    if (result.containsKey('error')) {
      setState(() {
        resultText = "Error";
        _isAnalyzing = false;
      });
      _showSnack("Offline: ${result['error']}", Colors.red);
    } else {
      bool isGenuine = result['isGenuine'];
      double dist = result['distance']; // not avg. since compares 2 images only
      
      setState(() {
        resultText = isGenuine ? "Genuine" : "Forged";
        confidence = dist;
        _isAnalyzing = false;
      });
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Signature Verifier", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              _isOfflineMode ? Icons.wifi_off : Icons.wifi,
              color: _isOfflineMode ? Colors.blueGrey : Colors.green,
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // [Online/Offline]
              const Text("Signature", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              _buildImageBox(_questionedImage, "No image selected"),
        
              // [Offline] Reference Image
              if (_isOfflineMode && _questionedImage != null) ...[
                const SizedBox(height: 20),
                const Text("Reference Signature (Genuine)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 5),
                InkWell(
                  onTap: pickReferenceImage,
                  child: _buildImageBox(
                    _referenceImage, 
                    "Tap to Add Reference", 
                    isPlaceholder: _referenceImage == null,
                    height: 180
                  ),
                ),
              ],
        
              const SizedBox(height: 20),
        
              // Results
              if (resultText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _getColorForResult(resultText),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isAnalyzing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Column(
                        children: [
                          Text(
                            resultText!,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          if (confidence != null)
                            Text(
                              "Distance: ${confidence!.toStringAsFixed(4)}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                          const SizedBox(height: 5),
                        ],
                      ),
                ),
              ],
        
              const SizedBox(height: 30),
        
              if (!_isOfflineMode || _questionedImage == null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildButton(Icons.camera_alt, "Camera", () => pickQuestionedImage(ImageSource.camera)),
                  const SizedBox(width: 20),
                  _buildButton(Icons.photo_library, "Gallery", () => pickQuestionedImage(ImageSource.gallery)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // for offline inference
  Widget _buildImageBox(File? file, String placeholder, {bool isPlaceholder = false, double height = 200}) {
    return Container(
      height: height,
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isPlaceholder ? Border.all(color: Colors.blueGrey, width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      clipBehavior: Clip.antiAlias,
      child: file != null
          ? Stack(
              children: [
                // Center the image inside the box using BoxFit.contain
                Center(
                  child: Image.file(
                    file, 
                    fit: BoxFit.contain, // Ensures whole signature is visible
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                placeholder, 
                style: TextStyle(color: isPlaceholder ? Colors.blueGrey : Colors.black),
              ),
            ),
    );
  }

  Widget _buildButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Color _getColorForResult(String? result) {
    if (result == "Genuine") return Colors.green;
    if (result == "Forged") return Colors.red;
    if (result == "[Offline] Reference Needed") return Colors.blueGrey;
    if (result == "Verifying..." || result == "Connecting..." || result == "Comparing Images...") return Colors.blue;
    return Colors.grey;
  }
}