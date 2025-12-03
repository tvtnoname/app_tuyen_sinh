import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({this.baseUrl = 'http://192.168.1.218:8080/api'});

  Future<Map<String, String>> _buildHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _buildHeaders();
    return http.get(uri, headers: headers);
  }

  Future<http.Response> post(String path, Object body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _buildHeaders();
    return http.post(uri, headers: headers, body: jsonEncode(body));
  }
}