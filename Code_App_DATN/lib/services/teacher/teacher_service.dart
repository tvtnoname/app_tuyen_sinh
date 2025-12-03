import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

class TeacherService {
  final AuthService _authService;

  TeacherService({AuthService? authService}) : _authService = authService ?? AuthService();

  // Lấy base URL từ authService.baseUrl

  String _apiBase() {
    var apiBase = _authService.baseUrl;
    if (apiBase.endsWith('/api/auth')) {
      apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
    }
    return apiBase;
  }

  /// Lấy tất cả các lớp được phân công cho giáo viên hiện tại

  Future<List<Map<String, dynamic>>> getTeacherClasses() async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      
      debugPrint('TeacherService call to $uri');
      debugPrint('Response status: ${resp.statusCode}');
      
      if (token != null) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            final normalized = base64Url.normalize(payload);
            final decoded = utf8.decode(base64Url.decode(normalized));
            debugPrint('Token Claims: $decoded');
          }
        } catch (e) {
          debugPrint('Error decoding token: $e');
        }
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        
        // Trích xuất từ data.teachingAssignments

        if (body['data'] is Map) {
          final data = body['data'] as Map<String, dynamic>;
          
          if (data['teachingAssignments'] is List) {
            final assignments = data['teachingAssignments'] as List;
            
            // Trích xuất clazz từ mỗi phân công và thêm số lượng học sinh

            return assignments.map((assignment) {
              if (assignment is Map && assignment['clazz'] is Map) {
                final clazz = Map<String, dynamic>.from(assignment['clazz'] as Map);
                
                // Lưu ý: studentCount có thể cần được lấy riêng
                // Hiện tại, chúng ta có thể sử dụng capacityMax hoặc lấy sau

                clazz['studentCount'] = clazz['capacityMax'] ?? 0;
                
                return clazz;
              }
              return <String, dynamic>{};
            }).where((c) => c.isNotEmpty).toList();
          }
        }
        
        return [];
      } else {
        throw Exception('Failed to load classes: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('TeacherService.getTeacherClasses error: $e');
      rethrow;
    }
  }

  /// Lấy danh sách học sinh trong một lớp cụ thể sử dụng endpoint grade

  Future<List<Map<String, dynamic>>> getClassStudents(int classId) async {
    try {
      final token = await _authService.getToken();
      // Sử dụng endpoint được yêu cầu: /api/teacher/grade?classId=...

      final uri = Uri.parse('${_apiBase()}/api/teacher/grade?classId=$classId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        
        List<dynamic> rawList = [];
        if (body['data'] is List) {
          rawList = body['data'] as List;
        }
        
        // Ánh xạ phản hồi sang cấu trúc tương thích với UI

        final List<Map<String, dynamic>> students = [];
        
        for (var item in rawList) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          // Trích xuất studentId
          int? studentId = map['studentId'];
          if (studentId == null && map['student'] is Map) {
             studentId = map['student']['studentId'];
          }
          
          // Lấy tên thật nếu studentId tồn tại

          if (studentId != null) {
             final realName = await _getStudentNameById(studentId);
             map['fullName'] = realName ?? 'Học viên $studentId';
          } else {
             map['fullName'] = 'Học viên (Unknown ID)';
          }
          
          students.add(map);
        }
        
        return students;
      } else {
        throw Exception('Failed to load students: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('TeacherService.getClassStudents error: $e');
      rethrow;
    }
  }

  /// Helper để lấy tên học sinh theo ID

  Future<String?> _getStudentNameById(int studentId) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/student/$studentId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['data'] is Map) {
          final data = body['data'] as Map;
          // Thử tìm tên trong đối tượng user hoặc trực tiếp trong data

          if (data['user'] is Map) {
            final user = data['user'] as Map;
            return user['fullName'] ?? user['userName'] ?? user['name'];
          }
          return data['fullName'] ?? data['name'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching name for student $studentId: $e');
      return null;
    }
  }

  /// Lấy lịch dạy của giáo viên từ phân công giảng dạy

  Future<Map<String, List<Map<String, dynamic>>>> getTeacherSchedule() async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        final Map<String, List<Map<String, dynamic>>> scheduleByDay = {
          'Thứ 2': [], 'Thứ 3': [], 'Thứ 4': [], 'Thứ 5': [], 'Thứ 6': [], 'Thứ 7': [], 'Chủ Nhật': []
        };

        if (body['data'] is Map) {
          final data = body['data'] as Map<String, dynamic>;
          if (data['teachingAssignments'] is List) {
            final assignments = data['teachingAssignments'] as List;
            
            for (var assignment in assignments) {
              if (assignment is! Map) continue;
              
              final clazz = assignment['clazz'];
              if (clazz is! Map) continue;
              
              final className = clazz['name'] ?? 'Lớp học';
              final subject = clazz['subject'] is Map ? clazz['subject']['name'] : 'Môn học';
              final classSchedules = clazz['classSchedules'];
              
              // Trích xuất ngày bắt đầu và kết thúc lớp học

              DateTime? classStart;
              DateTime? classEnd;
              try {
                final rawStart = clazz['startDate'] ?? clazz['start_date'] ?? clazz['start'];
                final rawEnd = clazz['endDate'] ?? clazz['end_date'] ?? clazz['end'];
                if (rawStart != null) {
                  classStart = DateTime.tryParse(rawStart.toString());
                }
                if (rawEnd != null) {
                  classEnd = DateTime.tryParse(rawEnd.toString());
                }
              } catch (_) {
                classStart = null;
                classEnd = null;
              }
              
              if (classSchedules is List) {
                for (var s in classSchedules) {
                  if (s is! Map) continue;
                  
                  int dayOfWeek = 0;
                  final rawDay = s['dayOfWeek'];
                  if (rawDay is int) {
                    dayOfWeek = rawDay;
                  } else if (rawDay is String) {
                    dayOfWeek = int.tryParse(rawDay) ?? 0;
                  }

                  String dayName = '';
                  // Quy ước API: 1=Thứ Hai (Thứ 2), 7=Chủ Nhật (Chủ Nhật)
                  switch (dayOfWeek) {
                    case 1: dayName = 'Thứ 2'; break;
                    case 2: dayName = 'Thứ 3'; break;
                    case 3: dayName = 'Thứ 4'; break;
                    case 4: dayName = 'Thứ 5'; break;
                    case 5: dayName = 'Thứ 6'; break;
                    case 6: dayName = 'Thứ 7'; break;
                    case 7: dayName = 'Chủ Nhật'; break;
                    default: dayName = 'Thứ ${dayOfWeek + 1}'; // Dự phòng
                  }
                  
                  // Nếu dayName không nằm trong các key map của chúng ta, bỏ qua

                  if (!scheduleByDay.containsKey(dayName)) {
                     continue;
                  }

                  final lessonSlot = s['lessonSlot'];
                  final room = s['room'];
                  
                  final startTime = lessonSlot is Map ? (lessonSlot['startTime'] ?? '') : '';
                  final endTime = lessonSlot is Map ? (lessonSlot['endTime'] ?? '') : '';
                  final roomName = room is Map ? (room['name'] ?? '') : '';
                  final floor = room is Map ? (room['floor'] ?? '') : '';
                  
                  scheduleByDay[dayName]?.add({
                    'className': className,
                    'subject': subject,
                    'startTime': startTime,
                    'endTime': endTime,
                    'room': roomName,
                    'floor': floor,
                    'location': '$roomName - $floor',
                    'studentCount': clazz['capacityMax'] ?? 0,
                    'classStart': classStart,  // Thêm ngày bắt đầu lớp học
                    'classEnd': classEnd,      // Thêm ngày kết thúc lớp học

                    'classId': clazz['classId'] ?? clazz['id'],
                    'scheduleId': s['scheduleId'],
                    'classSchedules': classSchedules,
                  });
                }
              }
            }
          }
        }
        
        // Sắp xếp sự kiện theo thời gian bắt đầu

        scheduleByDay.forEach((key, events) {
          events.sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
        });
        
        return scheduleByDay;
      } else {
        throw Exception('Failed to load schedule: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('TeacherService.getTeacherSchedule error: $e');
      rethrow;
    }
  }

  /// Lấy thông tin hồ sơ giáo viên

  Future<Map<String, dynamic>?> getTeacherProfile() async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        
        if (body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        } else {
          return Map<String, dynamic>.from(body);
        }
      } else {
        debugPrint('getTeacherProfile failed: ${resp.statusCode} - ${resp.body}');
        throw Exception('Failed to load profile: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('TeacherService.getTeacherProfile error: $e');
      rethrow;
    }
  }

  /// Lấy chi tiết học sinh

  Future<Map<String, dynamic>?> getStudentDetail(int studentId) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/student/$studentId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      
      debugPrint('TeacherService.getStudentDetail: $uri');
      debugPrint('Response status: ${resp.statusCode}');
      debugPrint('Response body: ${resp.body}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        
        if (body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        } else {
          return Map<String, dynamic>.from(body);
        }
      } else {
        throw Exception('Failed to load student: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('TeacherService.getStudentDetail error: $e');
      rethrow;
    }
  }

  /// Cập nhật điểm số học sinh

  Future<bool> updateStudentGrade(int studentClassId, Map<String, dynamic> scores) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/grade/$studentClassId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode(scores);
      
      debugPrint('TeacherService.updateStudentGrade: $uri');
      debugPrint('Body: $body');

      final resp = await http.patch(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
      
      debugPrint('Response status: ${resp.statusCode}');
      debugPrint('Response body: ${resp.body}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        throw Exception('Failed to update grade: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('TeacherService.updateStudentGrade error: $e');
      rethrow;
    }
  }
  /// Gửi thông báo/nhận xét cho một học sinh cụ thể

  Future<bool> sendStudentNotification({
    required int studentId,
    required int classId,
    required String title,
    required String message,
  }) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/notify?studentId=$studentId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode({
        'classId': classId,
        'title': title,
        'message': message,
      });
      
      debugPrint('TeacherService.sendStudentNotification: $uri');
      debugPrint('Body: $body');

      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
      
      debugPrint('Response status: ${resp.statusCode}');
      debugPrint('Response body: ${resp.body}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        throw Exception('Failed to send notification: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('TeacherService.sendStudentNotification error: $e');
      rethrow;
    }
  }

  /// Lấy thông báo của giáo viên

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/notification');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        
        if (body['data'] is List) {
          return List<Map<String, dynamic>>.from(body['data']);
        }
        return [];
      } else {
        throw Exception('Failed to load notifications: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('TeacherService.getNotifications error: $e');
      // Trả về danh sách rỗng thay vì ném lỗi để tránh chặn dashboard

      return [];
    }
  }

  /// Đánh dấu thông báo là đã đọc

  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final token = await _authService.getToken();
      // Cập nhật theo pattern của Student/Parent: PATCH /api/teacher/notification/{id}/read
      final uri = Uri.parse('${_apiBase()}/api/teacher/notification/$notificationId/read');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      // Không cần body cho endpoint /read
      final resp = await http.patch(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        debugPrint('Failed to mark read: ${resp.statusCode} - ${resp.body}');
        return false;
      }
    } catch (e) {
      debugPrint('TeacherService.markNotificationAsRead error: $e');
      return false;
    }
  }

  /// Gửi thông báo cho tất cả học sinh trong một lớp

  Future<bool> sendClassNotification(int classId, String title, String message) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/notify/class?classId=$classId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode({
        "classId": classId,
        "title": title,
        "message": message,
        "shortMessage": message.length > 50 ? "${message.substring(0, 50)}..." : message,
        "sentVia": "MOBILE_APP",
        "notificationType": "COMMENT",
        "relatedEntityType": "CLASS",
        "relatedEntityId": classId,
        "isRead": 0,
        "deliveryStatus": "PENDING",
        "delFlag": 0,
        "createBy": "teacher",
        "remark": "Thông báo lớp học"
      });

      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        debugPrint('Failed to send class notification: ${resp.statusCode} - ${resp.body}');
        return false;
      }
    } catch (e) {
      debugPrint('TeacherService.sendClassNotification error: $e');
      return false;
    }
  }

  /// Gửi thông báo đến phụ huynh của học sinh
  Future<bool> notifyParent({
    required int parentId,
    required int classId,
    required String title,
    required String message,
  }) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/notify-parent?parentId=$parentId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode({
        'classId': classId.toString(),
        'title': title,
        'message': message,
        'notificationType': 'COMMENT',
        'sentVia': 'MOBILE_APP',
      });

      debugPrint('TeacherService.notifyParent: $uri');
      debugPrint('Body: $body');

      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));

      debugPrint('Response status: ${resp.statusCode}');
      debugPrint('Response body: ${resp.body}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        throw Exception('Failed to send parent notification: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('TeacherService.notifyParent error: $e');
      rethrow;
    }
  }

  /// Gửi thông báo cho tất cả phụ huynh trong lớp
  Future<bool> sendParentNotification(int classId, String title, String message) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/notify/parent');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode({
        'classId': classId.toString(),
        'title': title,
        'message': message,
        'sentVia': 'MOBILE_APP',
      });

      debugPrint('TeacherService.sendParentNotification: $uri');
      debugPrint('Body: $body');

      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));

      debugPrint('Response status: ${resp.statusCode}');
      debugPrint('Response body: ${resp.body}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        debugPrint('Failed to send parent notification: ${resp.statusCode} - ${resp.body}');
        return false;
      }
    } catch (e) {
      debugPrint('TeacherService.sendParentNotification error: $e');
      return false;
    }
  }
}
