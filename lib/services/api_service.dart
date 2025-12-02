/*
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // TODO: insert python server url
  //static const String baseUrl = "http://your-python-server-url.com";
  static const String baseUrl = "http://127.0.0.1:8000"; // TODO: change for emulator/device

  // REGISTER users
  static Future<bool> registerUser(String name) async {
    final url = Uri.parse("$baseUrl/register");

    var request = http.MultipartRequest("POST", url);
    request.fields["name"] = name;

    try {
      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print("API Error (registerUser): $e");
      return false;
    }
  }


  // INFERENCE
  // call this when user takes a picture
  static Future<Map<String, dynamic>> inference(
    String name,
    http.MultipartFile file,
  ) async {
    final uri = Uri.parse("$baseUrl/inference");
    final request = http.MultipartRequest("POST", uri);

    request.fields["name"] = name;
    request.files.add(file);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return jsonDecode(response.body);
  }
  
  // UPDATE signature
  static Future<Map<String, dynamic>> updateSignature(
    String name,
    http.MultipartFile file,
  ) async {
    final uri = Uri.parse("$baseUrl/update");
    final request = http.MultipartRequest("POST", uri);

    request.fields["name"] = name;
    request.files.add(file);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return jsonDecode(response.body);

  }

  // Helper to convert file path -> MultipartFile
  static Future<http.MultipartFile> fileFromPath(String field, String path) async {
    return await http.MultipartFile.fromPath(field, path);
  }

 
}
*/
