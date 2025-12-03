import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

class CartService {
  final AuthService _authService;

  CartService({AuthService? authService}) : _authService = authService ?? AuthService();

  // Lấy base URL từ authService.baseUrl

  String _apiBase() {
    var apiBase = _authService.baseUrl;
    if (apiBase.endsWith('/api/auth')) {
      apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
    }
    return apiBase;
  }

  Future<void> addItemToServer(Map<String, dynamic> item) async {
    final token = await _authService.getToken();
    final uri = Uri.parse('${_apiBase()}/api/student/cart/items');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

    // Server yêu cầu tối thiểu classId và quantity. Bao gồm các trường tùy chọn nếu có.

    final body = jsonEncode({
      'classId': item['id'] ?? item['classId'] ?? item['class_id'],
      'quantity': item['quantity'] ?? 1,
      'title': item['title'],
      'description': item['description'],
      'branch': item['branch'],
      'days': item['days'],
      'time': item['time'],
      'sessions': item['sessions'],
      'price': item['feeRaw'] ?? item['price'],
      'feeRaw': item['feeRaw'],
      'raw': item['raw'],
    });

    try {
      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        // Thành công

        return;
      } else if (resp.statusCode == 401) {
        // Không được phép

        throw Exception('Unauthorized (401). Please login again.');
      } else {
        // Thử phân tích thông báo lỗi từ body

        try {
          final Map<String, dynamic> j = jsonDecode(resp.body);
          final msg = j['message'] ?? j['msg'] ?? j['error'] ?? resp.body;
          throw Exception('Server error: $msg');
        } catch (_) {
          throw Exception('Server error: ${resp.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('CartService.addItemToServer error: $e');
      rethrow;
    }
  }

  Future<void> removeItemFromServer(int itemId) async {
    final token = await _authService.getToken();
    final uri = Uri.parse('${_apiBase()}/api/student/cart/items/$itemId');
    final headers = <String, String>{ 'Accept': 'application/json' };
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

    final resp = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 10));
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw Exception('Failed to remove item: ${resp.statusCode}');
  }

  Future<void> updateItemQuantityOnServer(int itemId, int quantity) async {
    final token = await _authService.getToken();
    final uri = Uri.parse('${_apiBase()}/api/student/cart/items/$itemId');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

    final body = jsonEncode({ 'quantity': quantity });

    final resp = await http.put(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw Exception('Failed to update quantity: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>?> getCartFromServer() async {
    final token = await _authService.getToken();
    final uri = Uri.parse('${_apiBase()}/api/student/cart');
    final headers = <String, String>{ 'Accept': 'application/json' };
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

    final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      try {
        final Map<String, dynamic> j = jsonDecode(resp.body) as Map<String, dynamic>;
        // Server trả về AjaxResult {code, msg, data: cart}

        if (j.containsKey('data')) return Map<String, dynamic>.from(j['data']);
        return j;
      } catch (e) {
        debugPrint('CartService.getCartFromServer: parse error $e');
        return null;
      }
    } else if (resp.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load cart: ${resp.statusCode}');
    }
  }
}