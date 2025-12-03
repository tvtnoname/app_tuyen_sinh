import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ParentService {
  final String baseUrl;

  ParentService({this.baseUrl = 'http://192.168.1.218:8080/api/parent'});

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Lấy hồ sơ phụ huynh

  Future<Map<String, dynamic>?> getParentProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(baseUrl), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching parent profile: $e');
      return null;
    }
  }

  // Lấy danh sách con (học sinh)

  Future<List<Map<String, dynamic>>> getChildren() async {
    try {
      final headers = await _getHeaders();
      // 1. Lấy hồ sơ phụ huynh để tìm ID học sinh

      final response = await http.get(Uri.parse(baseUrl), headers: headers);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final data = body['data'];
        
        List<dynamic> relationships = [];
        
        // Xử lý các cấu trúc dữ liệu khác nhau có thể trả về

        if (data is Map) {
          if (data['studentRelationships'] is List) {
            relationships = data['studentRelationships'];
          } else if (data['parent'] is Map && data['parent']['studentRelationships'] is List) {
            relationships = data['parent']['studentRelationships'];
          }
        }

        if (relationships.isEmpty) return [];

        // 2. Trích xuất ID học sinh

        final List<int> studentIds = [];
        for (var r in relationships) {
          if (r is Map && r['studentId'] != null) {
             studentIds.add(r['studentId']);
          }
        }

        // 3. Lấy chi tiết cho từng học sinh

        final List<Map<String, dynamic>> childrenDetails = [];
        for (var id in studentIds) {
          final detail = await getStudentDetail(id);
          if (detail != null) {
            childrenDetails.add(detail);
          }
        }
        
        return childrenDetails;
      }
      return [];
    } catch (e) {
      print('Error fetching children: $e');
      return [];
    }
  }
  // Lấy chi tiết học sinh theo ID

  Future<Map<String, dynamic>?> getStudentDetail(int studentId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/student/$studentId');

      final response = await http.get(uri, headers: headers);

      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        
        // Kiểm tra key 'data' hoặc trả về body trực tiếp nếu nó là object

        if (data['data'] != null) {

          return data['data'];
        } else

         return data;

      }
      return null;
    } catch (e) {
      // Error fetching student detail
      return null;
    }
  }
  // Cập nhật hồ sơ phụ huynh

  Future<bool> updateParentProfile(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse(baseUrl), 
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      print('Update failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      print('Error updating parent profile: $e');
      return false;
    }
  }


  // Lấy thông báo cho phụ huynh

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/notification');

      
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        
        if (body['data'] is List) {
          return List<Map<String, dynamic>>.from(body['data']);
        }
        return [];
      } else {

        return [];
      }
    } catch (e) {
      // Error loading notifications
      return [];
    }
  }

  /// Xác nhận thanh toán cho đơn đăng ký
  Future<Map<String, dynamic>> confirmEnrollmentPayment(int enrollmentId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/enrollment/$enrollmentId/confirm-payment');

      
      final response = await http.post(uri, headers: headers).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': body['msg'] ?? 'Xác nhận thanh toán thành công',
        };
      } else {
        return {
          'success': false,
          'message': body['msg'] ?? 'Xác nhận thanh toán thất bại',
        };
      }
    } catch (e) {
      // Error confirming payment
      return {
        'success': false,
        'message': 'Lỗi kết nối: $e',
      };
    }
  }

  /// Hủy đơn đăng ký
  Future<Map<String, dynamic>> cancelEnrollmentPayment(int enrollmentId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/enrollment/$enrollmentId/cancel-payment');

      
      final response = await http.post(uri, headers: headers).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': body['msg'] ?? 'Đã hủy đơn đăng ký thành công',
        };
      } else {
        return {
          'success': false,
          'message': body['msg'] ?? 'Hủy đơn đăng ký thất bại',
        };
      }
    } catch (e) {
      // Error canceling payment
      return {
        'success': false,
        'message': 'Lỗi kết nối: $e',
      };
    }
  }

  /// Đánh dấu thông báo đã đọc
  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/notification/$notificationId/read'),
        headers: headers,
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      // Error marking notification as read
      return false;
    }
  }
}
