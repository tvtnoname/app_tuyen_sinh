import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

class RegisteredCoursesService {
  final AuthService _authService;

  RegisteredCoursesService({AuthService? authService}) : _authService = authService ?? AuthService();

  String _apiBase() {
    var apiBase = _authService.baseUrl;
    if (apiBase.endsWith('/api/auth')) {
      apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
    }
    return apiBase;
  }

  /// Lấy danh sách khóa học/đăng ký của học sinh hiện tại.
  /// Thử GET /api/student/enrollments, nếu thất bại thử /api/student.

  Future<List<Map<String, dynamic>>> getCourses() async {
    final token = await _authService.getToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

    final candidates = [
      Uri.parse('${_apiBase()}/api/student/enrollments'),
      Uri.parse('${_apiBase()}/api/student/enrollments/list'),
      Uri.parse('${_apiBase()}/api/student'),
    ];

    for (final uri in candidates) {
      try {
        final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final body = jsonDecode(resp.body);
          // Hỗ trợ wrapper AjaxResult {data: [...]}

          List<dynamic>? list;
          if (body is Map && body['data'] is List) {
            list = body['data'] as List<dynamic>;
          } else if (body is List) {
            list = body;
          } else if (body is Map && body.containsKey('enrollments') && body['enrollments'] is List) {
            list = body['enrollments'] as List<dynamic>;
          }

          if (list != null) {
            // Ánh xạ từng đối tượng thô vào các trường tối thiểu được UI sử dụng

            final result = <Map<String, dynamic>>[];
            for (final it in list) {
              if (it is Map) {
                result.add(_mapEnrollmentToCourse(Map<String, dynamic>.from(it)));
              }
            }
            return result;
          } else {
            // Nếu endpoint trả về đối tượng student với studentClasses, ánh xạ chúng

            if (body is Map && (body['studentClasses'] is List || (body['data'] is Map && body['data']['studentClasses'] is List))) {
              final scList = body['studentClasses'] is List ? body['studentClasses'] as List<dynamic> : (body['data']?['studentClasses'] as List<dynamic>?);
              
              // Cố gắng trích xuất danh sách điểm danh

              final attendanceList = body['attendances'] is List 
                  ? body['attendances'] as List<dynamic> 
                  : (body['data'] is Map && body['data']['attendances'] is List 
                      ? body['data']['attendances'] as List<dynamic> 
                      : []);

              if (scList != null) {
                final result = <Map<String, dynamic>>[];
                for (final sc in scList) {
                  if (sc is Map) {
                    final course = _mapEnrollmentToCourse(Map<String, dynamic>.from(sc));
                    
                    // Tính toán thống kê điểm danh cho lớp này
                    final classId = course['classId'];
                    if (classId != null && attendanceList.isNotEmpty) {
                      final classAttendances = attendanceList.where((a) => a is Map && (a['classId'] == classId || a['class_id'] == classId)).toList();
                      final total = classAttendances.length;
                      
                      final present = classAttendances.where((a) {
                        final status = (a['status'] ?? '').toString().toUpperCase();
                        return status == 'PRESENT' || status == 'LATE';
                      }).length;
                      
                      final absent = classAttendances.where((a) {
                        final status = (a['status'] ?? '').toString().toUpperCase();
                        return status == 'ABSENT';
                      }).length;

                      final onTime = classAttendances.where((a) {
                         final status = (a['status'] ?? '').toString().toUpperCase();
                         return status == 'PRESENT';
                      }).length;
                      
                      course['attendance_total'] = total;
                      course['attendance_present'] = present;
                      course['attendance_absent'] = absent;
                      course['attendance_on_time'] = onTime;
                      
                      // Store the detailed attendance list for use in detail views
                      course['attendances'] = classAttendances.map((a) => Map<String, dynamic>.from(a as Map)).toList();
                    } else {
                      course['attendance_total'] = 0;
                      course['attendance_present'] = 0;
                      course['attendance_on_time'] = 0;
                      course['attendances'] = [];
                    }
                    
                    result.add(course);
                  }
                }
                return result;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('RegisteredCoursesService: GET $uri failed: $e');
        // Thử ứng viên tiếp theo

        continue;
      }
    }

    // Dự phòng trả về rỗng

    return [];
  }

  Map<String, dynamic> _mapEnrollmentToCourse(Map<String, dynamic> enrollment) {
    final Map<String, dynamic> course = {};

    // Thử các trường phổ biến
    // enrollment có thể bao gồm: subject, clazz, class, registrationDate, createdAt, status
    // Ưu tiên tên lớp (như tiêu đề CourseStoreScreen)

    String subject = '';
    // Thử tên clazz trước

    if (enrollment['clazz'] is Map && enrollment['clazz']['name'] != null) {
      subject = enrollment['clazz']['name'].toString();
    } else if (enrollment['name'] != null) {
       // Đôi khi chính enrollment có tên nếu đã được làm phẳng

      subject = enrollment['name'].toString();
    } 
    
    // Dự phòng tên môn học nếu không tìm thấy tên lớp

    if (subject.isEmpty) {
      if (enrollment['subject'] is Map && enrollment['subject']['name'] != null) {
        subject = enrollment['subject']['name'].toString();
      } else if (enrollment['clazz'] is Map && enrollment['clazz']['subject'] is Map && enrollment['clazz']['subject']['name'] != null) {
        subject = enrollment['clazz']['subject']['name'].toString();
      } else if (enrollment['subjectName'] != null) {
        subject = enrollment['subjectName'].toString();
      }
    }

    course['subject'] = subject.isNotEmpty ? subject : 'Khóa học';

    // Ngày đăng ký

    course['registrationDate'] = enrollment['registrationDate'] ?? enrollment['enrollmentDate'] ?? enrollment['createdAt'] ?? '';

    // Trạng thái

    course['status'] = enrollment['status'] ?? enrollment['enrollmentStatus'] ?? 'Chờ xác nhận';

    // classId nếu có

    int? classId;
    final dynamic cid = enrollment['classId'] ?? enrollment['clazz']?['classId'] ?? enrollment['clazz']?['id'];
    if (cid != null) {
      if (cid is int) classId = cid;
      else classId = int.tryParse(cid.toString());
    }
    course['classId'] = classId;

    // Ánh xạ các trường điểm số
    // Thử tìm 'grade' hoặc 'score' hoặc 'finalScore'

    final rawGrade = enrollment['grade'] ?? enrollment['score'] ?? enrollment['finalScore'] ?? enrollment['averageScore'];
    course['grade'] = rawGrade?.toString() ?? 'N/A';

    // Ánh xạ điểm tháng (logic ví dụ: thử 'monthlyScore' hoặc 'midTermScore' hoặc parse từ grade nếu là số)

    final rawMonthly = enrollment['monthlyScore'] ?? enrollment['midTermScore'] ?? enrollment['processScore'];
    if (rawMonthly != null) {
      if (rawMonthly is int) course['monthlyScores'] = rawMonthly;
      else if (rawMonthly is double) course['monthlyScores'] = rawMonthly.toInt();
      else course['monthlyScores'] = int.tryParse(rawMonthly.toString()) ?? 0;
    } else {
       // Dự phòng: nếu grade là số, có thể nhân 10? Chỉ là heuristic hoặc mặc định là 0

       course['monthlyScores'] = 0;
    }

    // Ánh xạ điểm chi tiết

    course['score_1'] = enrollment['score1'] ?? enrollment['score_1'];
    course['score_2'] = enrollment['score2'] ?? enrollment['score_2'];
    course['score_3'] = enrollment['score3'] ?? enrollment['score_3'];
    course['final_score'] = enrollment['finalScore'] ?? enrollment['final_score'] ?? enrollment['grade'] ?? enrollment['score'];

    // Ánh xạ nhận xét của giáo viên

    course['teacherComment'] = enrollment['comment'] ?? enrollment['remark'] ?? enrollment['teacherComment'] ?? enrollment['feedback'] ?? 'Chưa có nhận xét';

    // Lưu dữ liệu thô

    // Ánh xạ thông tin học kỳ
    if (enrollment['clazz'] is Map && enrollment['clazz']['semester'] is Map) {
      final sem = enrollment['clazz']['semester'];
      course['semester'] = {
        'id': sem['semesterId'] ?? sem['id'],
        'name': sem['name'] ?? '',
      };
    } else if (enrollment['semester'] is Map) {
       final sem = enrollment['semester'];
       course['semester'] = {
        'id': sem['semesterId'] ?? sem['id'],
        'name': sem['name'] ?? '',
      };
    } else {
      // Thử tìm semesterName hoặc semester_name
      final semName = enrollment['semesterName'] ?? enrollment['semester_name'] ?? enrollment['clazz']?['semesterName'];
      if (semName != null) {
        course['semester'] = {
          'id': null, // Không có ID thì dùng name làm key tạm hoặc bỏ qua lọc theo ID
          'name': semName.toString(),
        };
      }
    }

    // Ngày kết thúc khóa học
    String? endDateStr;
    if (enrollment['clazz'] is Map) {
      endDateStr = enrollment['clazz']['endDate'] ?? enrollment['clazz']['end_date'] ?? enrollment['clazz']['end'];
    } 
    if (endDateStr == null && enrollment['endDate'] != null) {
      endDateStr = enrollment['endDate'];
    }
    if (endDateStr == null && enrollment['end_date'] != null) {
      endDateStr = enrollment['end_date'];
    }
    
    debugPrint('DEBUG: Subject: ${course['subject']}, Raw EndDate: $endDateStr, Clazz: ${enrollment['clazz']}');

    course['endDate'] = endDateStr ?? '';

    return course;
  }
}