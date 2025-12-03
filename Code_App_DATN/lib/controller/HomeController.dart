import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../services/auth/auth_service.dart';
import '../services/student/registered_courses_service.dart';

class HomeController {
  final AuthService _authService;
  final RegisteredCoursesService _registeredService;

  HomeController({AuthService? authService, RegisteredCoursesService? registeredService})
      : _authService = authService ?? AuthService(),
        _registeredService = registeredService ?? RegisteredCoursesService();

  /// Trả về map chứa các trường dùng bởi Home.dart:
  /// {
  ///   "upcomingClass": { "classId":..., "className":..., "dateTime": DateTime, "timeLabel": "...", "branch": "...", "rawClazz": {...} },
  ///   "totalCourses": int,
  ///   "attendedSessions": int,
  ///   "absentSessions": int
  /// }
  ///
  /// Chiến lược:
  /// 1) Thử GET $apiBase/api/home -> nếu API trả data map, dùng luôn.
  /// 2) Nếu không, lấy enrollments từ RegisteredCoursesService.getCourses() và
  ///    cho mỗi course có classId gọi GET /api/home/class/{id} để tìm buổi học tiếp theo.
  Future<Map<String, dynamic>> getHomeData() async {
    // try server-provided endpoint first
    try {
      String apiBase = _authService.baseUrl;
      if (apiBase.endsWith('/api/auth')) {
        apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
      }
      final uri = Uri.parse('$apiBase/api/home');
      final token = await _authService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        try {
          final body = jsonDecode(resp.body);
          if (body is Map && body.containsKey('data') && body['data'] is Map) {
            return Map<String, dynamic>.from(body['data']);
          } else if (body is Map) {
            return Map<String, dynamic>.from(body);
          }
        } catch (e) {
          debugPrint('HomeController: parse /api/home response error: $e');
        }
      } else {
        debugPrint('HomeController: /api/home returned ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('HomeController: error calling /api/home: $e');
    }

    // fallback: build from enrollments + class details
    try {
      final result = <String, dynamic>{
        'upcomingClass': null,
        'totalCourses': 0,
        'attendedSessions': 0,
        'absentSessions': 0,
      };

      final enrollments = await _registeredService.getCourses();
      result['totalCourses'] = enrollments.length;

      // compute next session among enrollments
      final now = DateTime.now();
      DateTime? bestDt;
      Map<String, dynamic>? bestInfo;

      for (final e in enrollments) {
        final dynamic cidRaw = e['classId'] ?? e['raw']?['classId'] ?? e['raw']?['clazz']?['classId'];
        final int? classId = (cidRaw is int) ? cidRaw : (cidRaw != null ? int.tryParse(cidRaw.toString()) : null);
        if (classId == null) continue;

        final clazz = await _fetchClassById(classId);
        if (clazz == null) continue;

        final candidate = _nextSessionForClazz(clazz, now);
        if (candidate != null) {
          final dt = candidate['dateTime'] as DateTime;
          if (bestDt == null || dt.isBefore(bestDt)) {
            bestDt = dt;
            bestInfo = {
              'classId': classId,
              'className': clazz['name'] ?? clazz['code'] ?? e['subject'] ?? 'Khóa học',
              'dateTime': dt,
              'timeLabel': candidate['timeLabel'],
              'branch': (clazz['branch'] is Map) ? (clazz['branch']['address'] ?? clazz['branch']['name']) : (clazz['branch'] ?? ''),
              'rawClazz': clazz,
            };
          }
        }
      }

      result['upcomingClass'] = bestInfo;
      // attendedSessions / absentSessions not computable here; keep 0 or extend logic
      result['attendedSessions'] = 0;
      result['absentSessions'] = 0;
      return result;
    } catch (e) {
      debugPrint('HomeController fallback error: $e');
      return {
        'upcomingClass': null,
        'totalCourses': 0,
        'attendedSessions': 0,
        'absentSessions': 0,
      };
    }
  }

  // Fetch class detail from /api/home/class/{id}
  Future<Map<String, dynamic>?> _fetchClassById(int id) async {
    try {
      String apiBase = _authService.baseUrl;
      if (apiBase.endsWith('/api/auth')) {
        apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
      }
      final uri = Uri.parse('$apiBase/api/home/class/$id');
      final token = await _authService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body.containsKey('data') && body['data'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(body['data'] as Map<String, dynamic>);
        } else {
          return Map<String, dynamic>.from(body);
        }
      } else {
        debugPrint('HomeController._fetchClassById status ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('HomeController._fetchClassById error: $e');
    }
    return null;
  }

  // compute next session for a class object (same logic as used in UI)
  Map<String, dynamic>? _nextSessionForClazz(Map<String, dynamic> clazz, DateTime from) {
    try {
      DateTime? classStart;
      DateTime? classEnd;
      final rawStart = clazz['startDate'] ?? clazz['start_date'] ?? clazz['start'];
      final rawEnd = clazz['endDate'] ?? clazz['end_date'] ?? clazz['end'];
      if (rawStart != null) {
        final p = DateTime.tryParse(rawStart.toString());
        if (p != null) {
          final loc = p.toLocal();
          classStart = DateTime(loc.year, loc.month, loc.day);
        }
      }
      if (rawEnd != null) {
        final p = DateTime.tryParse(rawEnd.toString());
        if (p != null) {
          final loc = p.toLocal();
          classEnd = DateTime(loc.year, loc.month, loc.day);
        }
      }

      final schedules = (clazz['classSchedules'] is List) ? List.from(clazz['classSchedules'] as List) : (clazz['schedules'] is List ? List.from(clazz['schedules'] as List) : []);
      if (schedules.isEmpty) return null;

      DateTime now = from;
      DateTime? best;
      String? bestTimeLabel;

      for (final s in schedules) {
        if (s is! Map) continue;
        final int? dow = _tryParseInt(s['dayOfWeek'] ?? s['day_of_week'] ?? s['day']);
        if (dow == null) continue;

        dynamic lesson = s['lessonSlot'] ?? s['lesson_slot'] ?? s['lesson'];
        String stStr = '';
        String etStr = '';
        if (lesson is Map) {
          stStr = lesson['startTime']?.toString() ?? lesson['start_time']?.toString() ?? '';
          etStr = lesson['endTime']?.toString() ?? lesson['end_time']?.toString() ?? '';
        } else {
          stStr = s['startTime']?.toString() ?? s['start_time']?.toString() ?? s['time']?.toString() ?? '';
          etStr = s['endTime']?.toString() ?? s['end_time']?.toString() ?? '';
        }
        if (stStr.isEmpty) continue;

        DateTime candidateDate = _nextDateForWeekdayFrom(now, dow);

        if (classStart != null && candidateDate.isBefore(classStart)) {
          candidateDate = _firstWeekdayOnOrAfter(classStart, dow);
        }

        final timeParts = stStr.split(':');
        int hour = 0;
        int minute = 0;
        if (timeParts.length >= 2) {
          hour = int.tryParse(timeParts[0]) ?? 0;
          minute = int.tryParse(timeParts[1]) ?? 0;
        } else {
          hour = int.tryParse(stStr) ?? 0;
        }
        DateTime candidateDateTime = DateTime(candidateDate.year, candidateDate.month, candidateDate.day, hour, minute);

        if (candidateDateTime.isBefore(now)) {
          candidateDateTime = candidateDateTime.add(const Duration(days: 7));
        }

        if (classEnd != null) {
          final lastValid = DateTime(classEnd.year, classEnd.month, classEnd.day, 23, 59, 59);
          if (candidateDateTime.isAfter(lastValid)) {
            continue;
          }
        }

        if (best == null || candidateDateTime.isBefore(best)) {
          best = candidateDateTime;
          final etLabel = etStr.isNotEmpty ? ' - ${_formatTimeValue(etStr)}' : '';
          bestTimeLabel = '${_formatTimeValue(stStr)}$etLabel';
        }
      }

      if (best != null) return {'dateTime': best, 'timeLabel': bestTimeLabel ?? ''};
    } catch (e) {
      debugPrint('HomeController._nextSessionForClazz error: $e');
    }
    return null;
  }

  DateTime _nextDateForWeekdayFrom(DateTime from, int weekday) {
    int offset = (weekday - from.weekday) % 7;
    if (offset < 0) offset += 7;
    return DateTime(from.year, from.month, from.day).add(Duration(days: offset));
  }

  DateTime _firstWeekdayOnOrAfter(DateTime date, int weekday) {
    int offset = (weekday - date.weekday) % 7;
    if (offset < 0) offset += 7;
    return DateTime(date.year, date.month, date.day).add(Duration(days: offset));
  }

  String _formatTimeValue(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    final parts = s.split(':');
    if (parts.length >= 2) return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    return s;
  }

  int? _tryParseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}