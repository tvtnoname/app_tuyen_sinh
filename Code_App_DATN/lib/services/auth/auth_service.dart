import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class AuthService {
  /// Base URL hiện trỏ đến root của auth controller; chúng ta sẽ
  /// lấy API base (bỏ /api/auth) khi gọi các endpoint profile.

  final String baseUrl;

  AuthService({this.baseUrl = 'http://192.168.1.218:8080/api/auth'});

  /// POST /api/auth/login
  Future<User> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/login');
    final body = jsonEncode({
      'userName': username,
      'password': password,
    });

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final resp = await http.post(uri, headers: headers, body: body);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String errorMessage;
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        errorMessage = 'Sai tên đăng nhập hoặc mật khẩu.';
      } else {
        errorMessage = 'Lỗi kết nối đến server (${resp.statusCode}).';
      }

      try {
        final Map<String, dynamic> errorBody = jsonDecode(resp.body);
        errorMessage = errorBody['message'] ?? errorBody['msg'] ?? errorBody['error'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Phản hồi không phải JSON: ${resp.body}');
    }

    // Xử lý wrapper mã AjaxResult

    if (json.containsKey('code')) {
      final code = json['code'];
      if (code != null && code is int && code != 200) {
        final msg = json['message'] ?? json['msg'] ?? 'Đăng nhập thất bại';
        throw Exception(msg);
      }
    }

    String? token;
    Map<String, dynamic>? userJson;
    final data = json['data'];

    if (data is String) {
      token = data;
    } else if (data is Map) {
      final d = Map<String, dynamic>.from(data);
      if (d.containsKey('user') && d['user'] is Map) {
        userJson = Map<String, dynamic>.from(d['user']);
      } else {
        userJson = Map<String, dynamic>.from(d);
      }
      token = d['token'] ?? d['accessToken'] ?? d['jwt'];
    }

    token ??= json['token'] ?? json['accessToken'] ?? json['jwt'];

    // Nếu đối tượng user tồn tại trong phản hồi -> phân tích và lưu token

    if (userJson != null) {
      final merged = Map<String, dynamic>.from(userJson);
      if (merged['token'] == null && token != null) merged['token'] = token;
      User user = User.fromJson(merged);

      // Nếu role bị thiếu, thử giải mã token

      if ((user.role == null || user.role!.isEmpty) && token != null) {
        final claims = _decodeJwtPayload(token);
        final roleFromClaims = claims != null ? _extractRoleFromClaims(claims) : null;
        if (roleFromClaims != null) user = user.copyWith(role: _normalizeRole(roleFromClaims));
      }

      // Lưu token (ưu tiên user.token nếu có)

      if (user.token != null) {
        await _saveToken(user.token!);
      } else if (token != null) {
        await _saveToken(token);
      }
      
      // Cập nhật ID cho ChatBot ngay khi đăng nhập thành công
      if (user.id != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chat_user_id', user.id.toString());
        print('Header: Đã cập nhật chat_user_id = ${user.id}');
      }

      return user;
    }

    // Nếu chỉ trả về token (không có đối tượng user)

    if (userJson == null && token != null) {
      User user = User(userName: username, token: token);

      // Giải mã token để lấy role và các claim chung

      final claims = _decodeJwtPayload(token);
      if (claims != null) {
        final role = _extractRoleFromClaims(claims);
        final fullName = claims['fullName'] ?? claims['name'] ?? claims['displayName'] ?? claims['sub'];
        final email = claims['email'] ?? claims['mail'];
        final phone = claims['phone'] ?? claims['mobile'];
        final idClaim = claims['userId'] ?? claims['user_id'] ?? claims['uid'] ?? claims['sub'];

        user = user.copyWith(
          role: user.role ?? (role != null ? _normalizeRole(role) : null),
          fullName: user.fullName ?? (fullName?.toString()),
          email: user.email ?? (email?.toString()),
          phone: user.phone ?? (phone?.toString()),
          id: user.id ?? (idClaim != null ? _tryParseInt(idClaim) : null),
        );
      }

      await _saveToken(token);

      // Cập nhật ID cho ChatBot ngay khi đăng nhập thành công
      if (user.id != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chat_user_id', user.id.toString());
        print('Header: Đã cập nhật chat_user_id = ${user.id}');
      }

      return user;
    }

    throw Exception(json['message'] ?? 'Không nhận được token từ server');
  }

  /// Lấy hồ sơ từ endpoint thích hợp.
  /// Logic:
  ///  - Nếu token chứa role -> gọi endpoint cho role đó trước (/api/student|/api/parent|/api/teacher)
  ///  - Nếu không, thử các endpoint chung theo thứ tự

  Future<User?> fetchProfile({String? username}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;

    // Lấy API base từ baseUrl (bỏ /api/auth nếu có)

    String apiBase = baseUrl;
    if (apiBase.endsWith('/api/auth')) {
      apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
    }

    // Thử lấy role từ token

    String? role;
    final claims = _decodeJwtPayload(token);
    if (claims != null) {
      final r = _extractRoleFromClaims(claims);
      if (r != null) role = _normalizeRole(r);
    }

    // Xây dựng danh sách URI ứng viên

    final List<Uri> candidates = [];

    if (role != null) {
      switch (role) {
        case 'STUDENT':
          candidates.add(Uri.parse('$apiBase/api/student'));
          break;
        case 'PARENT':
          candidates.add(Uri.parse('$apiBase/api/parent'));
          break;
        case 'TEACHER':
          candidates.add(Uri.parse('$apiBase/api/teacher'));
          break;
      }
    }

    // Thêm endpoint student dựa trên username nếu được cung cấp

    if (username != null && username.isNotEmpty) {
      candidates.add(Uri.parse('$apiBase/api/student?userName=${Uri.encodeComponent(username)}'));
    }

    // Danh sách dự phòng (thử student/parent/teacher)

    candidates.add(Uri.parse('$apiBase/api/student'));
    candidates.add(Uri.parse('$apiBase/api/parent'));
    candidates.add(Uri.parse('$apiBase/api/teacher'));

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    for (final uri in candidates) {
      try {
        debugPrint('fetchProfile: trying $uri');
        final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 401) {
          // Token không hợp lệ/hết hạn

          throw Exception('Unauthorized (401)');
        }
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          debugPrint('fetchProfile: success from $uri');
          final Map<String, dynamic> json = jsonDecode(resp.body) as Map<String, dynamic>;
          Map<String, dynamic>? source;

          // Các dạng phổ biến:
          // { code, msg, data: { ... } } trong đó data có thể chứa 'user' hoặc giống user

          if (json.containsKey('data')) {
            final data = json['data'];
            if (data is Map<String, dynamic>) {
              // Nếu tồn tại 'user' lồng nhau, ưu tiên nó

              if (data['user'] is Map<String, dynamic>) {
                // Use data as source to preserve outer fields (like schoolName in student object)
                // User.fromJson handles nested 'user' merging.
                source = Map<String, dynamic>.from(data);
              } else if (data['parent'] is Map<String, dynamic>) {
                // Một số phản hồi có thể lồng parent -> user

                final p = data['parent'];
                if (p is Map && p['user'] is Map) source = Map<String, dynamic>.from(p['user']);
                else source = Map<String, dynamic>.from(data);
              } else if (data['teacher'] is Map<String, dynamic>) {
                final t = data['teacher'];
                if (t is Map && t['user'] is Map) source = Map<String, dynamic>.from(t['user']);
                else source = Map<String, dynamic>.from(data);
              } else {
                source = Map<String, dynamic>.from(data);
              }
            }
          }

          // 'user' ở cấp gốc

          if (source == null && json['user'] is Map) {
            source = Map<String, dynamic>.from(json['user']);
          }

          // 'parent' hoặc 'teacher' ở cấp gốc chứa user lồng nhau

          if (source == null && json['parent'] is Map) {
            final p = json['parent'];
            if (p is Map && p['user'] is Map) source = Map<String, dynamic>.from(p['user']);
            else source = Map<String, dynamic>.from(p);
          }
          if (source == null && json['teacher'] is Map) {
            final t = json['teacher'];
            if (t is Map && t['user'] is Map) source = Map<String, dynamic>.from(t['user']);
            else source = Map<String, dynamic>.from(t);
          }

          // Dự phòng: có thể chính json là dạng user (có userId/userName/fullName/email)

          if (source == null && (json.containsKey('userId') || json.containsKey('userName') || json.containsKey('fullName') || json.containsKey('email'))) {
            source = Map<String, dynamic>.from(json);
          }

          if (source != null) {
            if (source['token'] == null) source['token'] = token;
            User user = User.fromJson(source);
            
            // BẮT BUỘC ROLE nếu chúng ta gọi endpoint parent và nhận được phản hồi hợp lệ

            if (uri.toString().contains('/api/parent')) {
               debugPrint('fetchProfile: forcing role to PARENT');
               user = user.copyWith(role: 'PARENT');
            } else if (uri.toString().contains('/api/teacher')) {
               user = user.copyWith(role: 'TEACHER');
            } else if (uri.toString().contains('/api/student')) {
               user = user.copyWith(role: 'STUDENT');
            }
            
            return user.token != null ? user : user.copyWith(token: token);
          } else {
            // Không tìm thấy user trong phản hồi này; tiếp tục với ứng viên tiếp theo

            continue;
          }
        } else {
          // Không phải 2xx - thử tiếp theo

          continue;
        }
      } catch (e) {
        // Nếu Unauthorized, ném lại ngoại lệ để caller xử lý logout

        if (e.toString().contains('Unauthorized') || e.toString().contains('401')) {
          rethrow;
        }
        // Ngược lại bỏ qua và thử endpoint tiếp theo

        debugPrint('fetchProfile candidate error ($uri): $e');
        continue;
      }
    }

    // Không tìm thấy hồ sơ

    return null;
  }

  // Giải mã payload JWT

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> claims = jsonDecode(decoded) as Map<String, dynamic>;
      return claims;
    } catch (_) {
      return null;
    }
  }

  // Trích xuất role từ claims

  String? _extractRoleFromClaims(Map<String, dynamic> claims) {
    if (claims['role'] != null) return claims['role'].toString();
    if (claims['roles'] != null) {
      final r = claims['roles'];
      if (r is List && r.isNotEmpty) return r.first.toString();
      if (r is String) return r.toString().split(',').first.trim();
    }
    if (claims['authorities'] != null) {
      final a = claims['authorities'];
      if (a is List && a.isNotEmpty) return a.first.toString();
      if (a is String) return a.toString().split(',').first.trim();
    }
    return null;
  }

  String _normalizeRole(String raw) {
    return raw.replaceAll('ROLE_', '').toUpperCase();
  }

  int? _tryParseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// POST /api/auth/change-password
  Future<void> changePassword(String oldPassword, String newPassword, String confirmPassword) async {
    // Lấy API base từ baseUrl (bỏ /api/auth nếu có, sau đó thêm /api/auth/change-password)
    // Thực tế, dựa trên hình ảnh người dùng, URL là http://localhost:8080/api/auth/change-password
    // và baseUrl hiện tại là http://192.168.1.218:8080/api/auth
    // Vì vậy chúng ta chỉ cần thêm /change-password vào baseUrl.


    final uri = Uri.parse('$baseUrl/change-password');
    final token = await getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'oldPassword': oldPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });

    final resp = await http.post(uri, headers: headers, body: body);

    print('ChangePassword Response Status: ${resp.statusCode}');
    print('ChangePassword Response Body: ${resp.body}');

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      if (resp.statusCode == 503) {
        throw Exception('Mật khẩu cũ không chính xác');
      }
      String errorMessage = 'Đổi mật khẩu thất bại (${resp.statusCode})';
      try {
        final Map<String, dynamic> errorBody = jsonDecode(resp.body);
        errorMessage = errorBody['message'] ?? errorBody['msg'] ?? errorBody['error'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
    
    // Kiểm tra lỗi logic trong phản hồi 200 OK nếu có (ví dụ: code != 200)

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(resp.body);
    } catch (_) {
      // ignored, not json or parsing failed, assume success if status was 200
    }

    if (json != null && json.containsKey('code')) {
      final code = json['code'];
      // Chấp nhận 200 là thành công. Một số API có thể sử dụng chuỗi "200".

      if (code != 200 && code.toString() != '200') {
         final msg = json['msg'] ?? json['message'] ?? '';
         // Xử lý các trường hợp lỗi cụ thể

         if (code == 503 || code == 500 || msg.toString().contains('Old password is incorrect')) {
            throw Exception('Mật khẩu cũ không chính xác');
         }
         throw Exception(msg.toString().isNotEmpty ? msg : 'Đổi mật khẩu thất bại');
      }
    }
  }
}