import 'dart:convert'; // Needed to parse the JSON response
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // CONFIG: Change this to your current IP address
  static const String baseUrl = "http://172.26.48.20:8000"; 

  // 1. REGISTER (New User)
  static Future<void> registerUser({
    required String userName,
    required List<File> imageFiles,
  }) async {
    final uri = Uri.parse('$baseUrl/register?name=$userName');
    var request = http.MultipartRequest('POST', uri);

    for (var image in imageFiles) {
      var multipartFile = await http.MultipartFile.fromPath(
        'files',
        image.path,
      );
      request.files.add(multipartFile);
    }

    await _sendRequest(request, "Register");
  }

  // 2. UPDATE (Add 1 signature for training)
  static Future<void> uploadSignature({
    required String userName,
    required File imageFile,
  }) async {
    final uri = Uri.parse('$baseUrl/update?name=$userName');
    var request = http.MultipartRequest('POST', uri);

    var multipartFile = await http.MultipartFile.fromPath(
      'file', // Matches main.py: file: UploadFile
      imageFile.path,
    );
    request.files.add(multipartFile);

    await _sendRequest(request, "Update");
  }

  // 3. INFERENCE (Verify Signature)
  static Future<Map<String, dynamic>?> verifySignature({
    required String userName,
    required File imageFile,
  }) async {
    final uri = Uri.parse('$baseUrl/inference?name=$userName');
    var request = http.MultipartRequest('POST', uri);

    var multipartFile = await http.MultipartFile.fromPath(
      'new_signature', 
      imageFile.path,
    );
    request.files.add(multipartFile);

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Parse the JSON: {"Result": "Genuine", "Avg. distance": 0.5}
        return jsonDecode(response.body);
      } else {
        print("Inference Failed: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error calling inference: $e");
      return null;
    }
  }

  // Helper to keep code clean
  static Future<void> _sendRequest(http.MultipartRequest request, String tag) async {
    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        print("$tag Success: ${response.body}");
      } else {
        print("$tag Failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error during $tag: $e");
    }
  }
}