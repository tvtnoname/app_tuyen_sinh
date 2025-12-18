import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  // URL của Chatbot (Local Server)
  // Sử dụng IP LAN để chạy được trên cả Máy thật và Emulator
  final String baseUrl = "http://192.168.1.218:8000";
  
  String? _sessionId;
  String? _userId;

  /// Tạo UUID v4 đơn giản
  String _generateUuid() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    
    // Set version (4) and variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    
    return '${_bytesToHex(bytes.sublist(0, 4))}-'
        '${_bytesToHex(bytes.sublist(4, 6))}-'
        '${_bytesToHex(bytes.sublist(6, 8))}-'
        '${_bytesToHex(bytes.sublist(8, 10))}-'
        '${_bytesToHex(bytes.sublist(10, 16))}';
  }
  
  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Helper: Làm sạch ID, chỉ giữ lại chữ, số và dấu gạch ngang
  String _cleanId(String? raw) {
    if (raw == null) return "";
    // Chỉ giữ lại: a-z, A-Z, 0-9, -
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
  }

  /// Lấy User ID (Ưu tiên từ Token đăng nhập và PHẢI LÀ SỐ để khớp với Database)
  Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Thử lấy ID từ Token đăng nhập (nếu user đã đăng nhập)
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final decoded = utf8.decode(base64Url.decode(normalized));
          final Map<String, dynamic> claims = jsonDecode(decoded);
          
          final candidates = [
            claims['userId'], 
            claims['user_id'], 
            claims['id'], 
            claims['uid'],
            claims['sub'] 
          ];

          for (final candidate in candidates) {
            if (candidate != null) {
              final s = candidate.toString();
              if (int.tryParse(s) != null) {
                 return s;
              }
            }
          }
        }
      } catch (e) {
        print('ChatService: Lỗi decode token: $e');
      }
    }

    // 2. Fallback: Dùng ID khách (stored)
    String? storedId = prefs.getString('chat_user_id');
    
    // 3. Làm sạch ID khách (quan trọng: xóa ngoặc [] nếu có)
    if (storedId != null) {
       final clean = _cleanId(storedId);
       if (clean != storedId && clean.isNotEmpty) {
          await prefs.setString('chat_user_id', clean);
          storedId = clean;
       }
    }

    if (storedId == null || storedId.isEmpty) {
      storedId = _generateUuid();
      await prefs.setString('chat_user_id', storedId);
    }
    
    // Đảm bảo kết quả trả về luôn sạch
    return _cleanId(storedId);
  }

  /// Đặt session ID hiện tại
  void setSessionId(String sessionId) {
    _sessionId = sessionId;
  }

  /// Reset session (bắt đầu cuộc hội thoại mới)
  void resetSession() {
    _sessionId = null;
  }

  /// Gửi câu hỏi đến Chatbot và nhận câu trả lời (legacy method)
  Future<String> sendMessage(String question) async {
    try {
      final userId = await getUserId();
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'question': question,
          'user_id': userId,
          'session_id': _sessionId,
        }),
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        
        // Cập nhật session ID nếu có
        if (data['session_id'] != null) {
          _sessionId = data['session_id'];
        }
        
        return data['answer'] ?? "Xin lỗi, tôi không hiểu câu hỏi.";
      } else {
        throw Exception('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Không thể kết nối đến Chatbot: $e');
    }
  }

  /// Gửi tin nhắn và nhận phản hồi dạng stream (cho typing effect)
  Stream<Map<String, dynamic>> streamSendMessage(String question) async* {
    final client = http.Client();
    try {
      final userId = await getUserId();
      
      final request = http.Request('POST', Uri.parse('$baseUrl/api/v1/stream'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      });
      request.body = jsonEncode({
        'question': question,
        'user_id': userId,
        if (_sessionId != null) 'session_id': _sessionId,
      });

      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception('Lỗi Server: ${response.statusCode}');
      }

      // Xử lý luồng sự kiện SSE
      print('✅ Connected to SSE stream');
      
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
            
        if (line.startsWith('data: ')) {
          // Cắt bỏ prefix "data: "
          final jsonString = line.substring(6);
          if (jsonString.trim().isEmpty) continue; // Skip heartbeats
          
          try {
            final data = jsonDecode(jsonString);
            
            // 1. Lưu session_id nếu có
            if (data['session_id'] != null) {
              _sessionId = data['session_id'];
              // print('Updated Session: $_sessionId');
            }

            // 2. Yield chunk ra UI
            // chunk có thể chứa text_chunk, options, courses
            yield data;
            
          } catch (e) {
            // Parse error
          }
        }
      }
      
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    } finally {
      client.close();
    }
  }

  /// Lấy lịch sử các cuộc hội thoại
  Future<List<Map<String, dynamic>>> getChatHistory() async {
    try {
      final userId = await getUserId();
      
      if (userId.isEmpty) {
        return [];
      }

      // New API: GET /api/v1/history/sessions?user_id={user_id}&limit=20
      final uri = Uri.parse('$baseUrl/api/v1/history/sessions').replace(
        queryParameters: {
          'user_id': userId,
          'limit': '20',
        },
      );
      
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        
        // API trả về mảng trực tiếp hoặc object chứa sessions
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['sessions'] is List) {
          return List<Map<String, dynamic>>.from(data['sessions']);
        }
        return [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Lấy chi tiết một session
  Future<List<Map<String, dynamic>>> getSessionDetails(String sessionId) async {
    try {
      // New API: GET /api/v1/history/{session_id}
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/history/$sessionId'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        
        // API trả về mảng tin nhắn trực tiếp hoặc object chứa messages
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['messages'] is List) {
          return List<Map<String, dynamic>>.from(data['messages']);
        }
        return [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Đổi tên session
  Future<bool> renameSession(String sessionId, String newTitle) async {
    try {
      // New API: PATCH /api/v1/history/{session_id}
      final response = await http.patch(
        Uri.parse('$baseUrl/api/v1/history/$sessionId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'title': newTitle}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Xóa session
  Future<bool> deleteSession(String sessionId) async {
    try {
      // New API: DELETE /api/v1/history/{session_id}
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/history/$sessionId'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
