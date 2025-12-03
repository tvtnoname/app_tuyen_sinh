import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../models/user.dart';
import '../auth/auth_service.dart';

class ScheduleService {
  final AuthService _authService;

  ScheduleService({AuthService? authService}) : _authService = authService ?? AuthService();

  // Tên các ngày sử dụng bởi UI

  static const List<String> daysOfWeek = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  /// Entry chính: trả về Map<dayName, List<eventMap>>
  /// Các trường của event map: subject, time, endTime, location, teacher, color
  /// Bây giờ bao gồm thêm:
  /// - 'classStart' : DateTime? (parse từ clazz.startDate)
  /// - 'classEnd'   : DateTime? (parse từ clazz.endDate)

  Future<Map<String, List<Map<String, dynamic>>>> getScheduleForUser(User user) async {
    // Khởi tạo kết quả với các danh sách rỗng

    final Map<String, List<Map<String, dynamic>>> schedule = {
      for (var d in daysOfWeek) d: <Map<String, dynamic>>[],
    };

    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('ScheduleService: no token available');
      return schedule;
    }

    // Lấy apiBase từ authService.baseUrl

    String apiBase = _authService.baseUrl;
    if (apiBase.endsWith('/api/auth')) {
      apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
    }

    try {
      if ((user.role ?? '').toUpperCase() == 'PARENT') {
        // 1) Lấy dữ liệu thô của phụ huynh để lấy ID học sinh liên quan

        final parentData = await _getRaw('/api/parent', token, apiBase);
        if (parentData != null) {
          final Set<int> studentIds = {};

          // Thử trích xuất từ parent.studentRelationships

          final rels = _extractList(parentData, ['studentRelationships', 'student_relationships', 'relationships']);
          if (rels != null) {
            for (final rel in rels) {
              if (rel is Map<String, dynamic>) {
                final sId = _tryParseInt(rel['studentId'] ?? rel['student_id']);
                if (sId != null) studentIds.add(sId);
              }
            }
          }
          // Cũng thử parent.user?.userId

          final nestedUser = _extractMap(parentData, ['user', 'userMap']);
          final pUserId = _tryParseInt(nestedUser?['userId'] ?? nestedUser?['user_id']);
          if (pUserId != null) studentIds.add(pUserId); // Đôi khi endpoint phụ huynh có thể bao gồm student? Vô hại


          // Với mỗi ID học sinh liên quan, lấy dữ liệu thô của học sinh và gộp lịch học

          for (final sid in studentIds) {
            final studentData = await _fetchStudentRawDataById(sid, token, apiBase);
            if (studentData != null) {
              await _addEventsFromStudentData(studentData, schedule);
            }
          }
        }
      } else {
        // Mặc định: coi user là STUDENT (hoặc giáo viên v.v. - chúng ta thử endpoint student)

        final studentData = await _getRaw('/api/student', token, apiBase);
        if (studentData != null) {
          await _addEventsFromStudentData(studentData, schedule);
        }
      }
    } catch (e, st) {
      debugPrint('ScheduleService.getScheduleForUser error: $e\n$st');
      // Khi có lỗi trả về những gì chúng ta có (có thể là lịch rỗng)

    }

    return schedule;
  }

  // Helper: lấy map JSON thô từ một endpoint (đường dẫn tương đối, trả về map 'data' nếu có wrapper)

  Future<Map<String, dynamic>?> _getRaw(String relativePath, String token, String apiBase) async {
    try {
      final uri = Uri.parse('$apiBase$relativePath');
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      debugPrint('ScheduleService._getRaw GET $uri -> ${resp.statusCode}');
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> jsonBody = jsonDecode(resp.body) as Map<String, dynamic>;
        if (jsonBody.containsKey('data') && jsonBody['data'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(jsonBody['data'] as Map<String, dynamic>);
        } else {
          return Map<String, dynamic>.from(jsonBody);
        }
      } else {
        debugPrint('ScheduleService._getRaw non-2xx: ${resp.statusCode} ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('ScheduleService._getRaw error: $e');
      return null;
    }
  }

  // Thử lấy học sinh theo id với một vài URL ứng viên

  Future<Map<String, dynamic>?> _fetchStudentRawDataById(int id, String token, String apiBase) async {
    final List<Uri> tries = [
      Uri.parse('$apiBase/api/student/$id'),
      Uri.parse('$apiBase/api/student?studentId=$id'),
      Uri.parse('$apiBase/api/student?userId=$id'),
    ];
    for (final uri in tries) {
      try {
        final headers = {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        };
        final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
        debugPrint('ScheduleService._fetchStudentRawDataById GET $uri -> ${resp.statusCode}');
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final Map<String, dynamic> jsonBody = jsonDecode(resp.body) as Map<String, dynamic>;
          if (jsonBody.containsKey('data') && jsonBody['data'] is Map<String, dynamic>) {
            return Map<String, dynamic>.from(jsonBody['data'] as Map<String, dynamic>);
          } else {
            return Map<String, dynamic>.from(jsonBody);
          }
        }
      } catch (e) {
        debugPrint('ScheduleService._fetchStudentRawDataById try failed for $uri: $e');
        continue;
      }
    }
    return null;
  }

  // Phân tích studentData và thêm sự kiện vào map lịch học

  Future<void> _addEventsFromStudentData(
    Map<String, dynamic> studentData, 
    Map<String, List<Map<String, dynamic>>> schedule,
  ) async {
    final token = await _authService.getToken();
    String apiBase = _authService.baseUrl;
    if (apiBase.endsWith('/api/auth')) {
      apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
    }
    final classes = _extractList(studentData, ['studentClasses', 'student_classes', 'classes']);
    if (classes == null) return;

    for (final sc in classes) {
      if (sc is Map<String, dynamic>) {
        final clazz = _extractMap(sc, ['clazz', 'class', 'clazzMap']);
        if (clazz == null) continue;

        final subject = (clazz['name']?.toString() ?? sc['name']?.toString()) ??
            ((clazz['subject'] is Map<String, dynamic> && clazz['subject']['name'] != null)
                ? clazz['subject']['name'].toString()
                : 'Khóa học');

        final branchName = (clazz['branch'] is Map && clazz['branch']['name'] != null) ? clazz['branch']['name'].toString() : null;

        final classSchedules = _extractList(clazz, ['classSchedules', 'class_schedules', 'schedules']);
        if (classSchedules == null) continue;

        // Lấy thông tin giáo viên từ classId
        String? teacherName;
        try {
          // Lấy classId từ dữ liệu lớp học
          final classId = _tryParseInt(clazz['classId'] ?? clazz['class_id']);
          
          if (classId != null && token != null) {
            // Gọi API /api/student/teacher/{classId} để lấy tên giáo viên
            final teacherInfo = await _getTeacherInfoByClassId(classId, token, apiBase);
            
            if (teacherInfo != null && teacherInfo['user'] is Map) {
              final user = teacherInfo['user'] as Map;
              teacherName = user['fullName']?.toString() ?? user['userName']?.toString();
            }
          }
        } catch (e) {
          debugPrint('ERROR Schedule: Error fetching teacher info: $e');
        }

        // Phân tích ngày bắt đầu/kết thúc cấp lớp nếu có, để đính kèm vào mỗi sự kiện

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

        // <-- MỚI: in ngày bắt đầu / kết thúc cho lớp này (debug)

        try {
          debugPrint('ScheduleService: Class="$subject" start=${classStart?.toIso8601String() ?? "null"} end=${classEnd?.toIso8601String() ?? "null"}');
        } catch (_) {}

        for (final cs in classSchedules) {
          if (cs is Map<String, dynamic>) {
            final dayOfWeek = _tryParseInt(cs['dayOfWeek'] ?? cs['day_of_week'] ?? cs['day']);
            if (dayOfWeek == null || dayOfWeek < 1 || dayOfWeek > 7) continue;
            final dayName = daysOfWeek[dayOfWeek - 1];
            
            debugPrint('SCHEDULE DEBUG: Class "$subject" - dayOfWeek=$dayOfWeek -> dayName="$dayName"');

            final lessonSlot = _extractMap(cs, ['lessonSlot', 'lesson_slot', 'lesson']);
            final startTime = lessonSlot != null
                ? (lessonSlot['startTime']?.toString() ?? lessonSlot['start_time']?.toString() ?? '')
                : (cs['time']?.toString() ?? cs['startTime']?.toString() ?? '');
            final endTime = lessonSlot != null
                ? (lessonSlot['endTime']?.toString() ?? lessonSlot['end_time']?.toString() ?? '')
                : (cs['endTime']?.toString() ?? cs['end_time']?.toString() ?? '');

            final location = (cs['room'] is Map && cs['room']['name'] != null)
                ? cs['room']['name'].toString()
                : (branchName ?? (cs['location']?.toString() ?? 'N/A'));

            // Xây dựng map sự kiện tương thích với mong đợi của UI

            final event = <String, dynamic>{
              'subject': subject,
              'time': startTime,
              'location': location,
              'endTime': endTime,
              'teacher': teacherName, // Tên giáo viên từ API

              // Màu tùy chọn theo môn học (hash đơn giản)

              'color': _colorForSubject(subject),
              // Đính kèm ngày bắt đầu/kết thúc cấp lớp để UI có thể lọc theo khoảng thời gian thực tế

              'classStart': classStart,
              'classEnd': classEnd,
            };

            schedule[dayName]?.add(event);
          }
        }
      }
    }
  }

  // Các tiện ích nhỏ

  List<dynamic>? _extractList(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] is List) return m[k] as List<dynamic>;
    }
    return null;
  }

  Map<String, dynamic>? _extractMap(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] is Map) return Map<String, dynamic>.from(m[k] as Map);
    }
    return null;
  }

  int? _tryParseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String _colorForSubject(String subject) {
    final key = subject.toLowerCase();
    if (key.contains('toán') || key.contains('toa')) return 'blue';
    if (key.contains('lý') || key.contains('vat') || key.contains('vật')) return 'green';
    if (key.contains('hóa') || key.contains('hoa')) return 'orange';
    if (key.contains('anh') || key.contains('english')) return 'red';
    return 'blue';
  }

  /// Lấy thông tin giáo viên từ API dựa trên classId
  Future<Map<String, dynamic>?> _getTeacherInfoByClassId(int classId, String token, String apiBase) async {
    try {
      final uri = Uri.parse('$apiBase/api/student/teacher/$classId');
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      debugPrint('ScheduleService._getTeacherInfoByClassId GET $uri -> ${resp.statusCode}');
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> jsonBody = jsonDecode(resp.body) as Map<String, dynamic>;
        if (jsonBody.containsKey('data') && jsonBody['data'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(jsonBody['data'] as Map<String, dynamic>);
        } else {
          return Map<String, dynamic>.from(jsonBody);
        }
      }
      return null;
    } catch (e) {
      debugPrint('ScheduleService._getTeacherInfoByClassId error: $e');
      return null;
    }
  }
}