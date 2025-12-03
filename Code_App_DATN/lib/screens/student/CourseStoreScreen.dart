import 'dart:convert';

import 'package:app_quan_ly_tuyen_sinh/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class CourseStoreScreen extends StatefulWidget {
  const CourseStoreScreen({super.key});

  @override
  State<CourseStoreScreen> createState() => _CourseStoreScreenState();
}

class _CourseStoreScreenState extends State<CourseStoreScreen> {
  // Services
  final AuthService _authService = AuthService();

  // Dữ liệu và bộ lọc
  List<Map<String, dynamic>> _allCourses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  bool _isLoading = true;

  // Trạng thái bộ lọc
  String? _selectedSubject;
  String? _selectedGrade;
  String? _selectedTime;
  String? _selectedBranch;

  List<String> _subjects = [];
  List<String> _grades = [];
  List<String> _times = [];
  List<String> _branches = [];

  final NumberFormat _decimal = NumberFormat.decimalPattern('vi');
  static const Map<int, String> _weekdayNames = {
    1: 'Thứ Hai',
    2: 'Thứ Ba',
    3: 'Thứ Tư',
    4: 'Thứ Năm',
    5: 'Thứ Sáu',
    6: 'Thứ Bảy',
    7: 'Chủ Nhật',
  };

  @override
  void initState() {
    super.initState();
    _loadCourseData();
  }

  /// Tải dữ liệu khóa học từ API.
  Future<void> _loadCourseData() async {
    setState(() => _isLoading = true);
    try {
      // Xây dựng URL API từ AuthService.baseUrl (loại bỏ /api/auth nếu có)
      String apiBase = _authService.baseUrl;
      if (apiBase.endsWith('/api/auth')) {
        apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
      }
      final uri = Uri.parse('$apiBase/api/home/class');

      final token = await _authService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Lỗi server: ${resp.statusCode}');
      }

      final Map<String, dynamic> body = json.decode(resp.body) as Map<String, dynamic>;
      final List<dynamic>? dataList = body['data'] is List ? body['data'] as List<dynamic> : null;
      if (dataList == null) {
        // Có thể API trả về trực tiếp một mảng -> thử decode resp.body dưới dạng List
        try {
          final List<dynamic> alt = json.decode(resp.body) as List<dynamic>;
          _processClassesList(alt);
        } catch (_) {
          throw Exception('API trả về format không hợp lệ');
        }
      } else {
        _processClassesList(dataList);
      }

      _extractFilterOptions();
    } catch (e) {
      debugPrint('Error loading classes from API: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tải được danh sách khóa học: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Định dạng giá trị thời gian (HH:mm).
  String _formatTimeValue(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    final parts = s.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return s;
  }

  /// Xử lý danh sách lớp học trả về từ API.
  void _processClassesList(List<dynamic> dataList) {
    _allCourses = dataList.map<Map<String, dynamic>>((item) {
      final Map<String, dynamic> clazz = Map<String, dynamic>.from(item as Map);
      final int? classId = _tryParseInt(clazz['classId'] ?? clazz['class_id'] ?? clazz['id']);
      final String title = clazz['name']?.toString() ?? clazz['code']?.toString() ?? 'Khóa học';

      String subjectName = '';
      try {
        if (clazz['subject'] is Map && clazz['subject']['name'] != null) subjectName = clazz['subject']['name'].toString();
      } catch (_) {}
      String gradeName = '';
      try {
        if (clazz['grade'] is Map && clazz['grade']['name'] != null) gradeName = clazz['grade']['name'].toString();
      } catch (_) {}
      final String description = [subjectName, gradeName].where((s) => s.isNotEmpty).join(' · ');

      // Địa chỉ chi nhánh (ưu tiên địa chỉ, fallback về tên)
      String branch = 'N/A';
      try {
        if (clazz['branch'] is Map) {
          final b = clazz['branch'] as Map;
          final addr = b['address']?.toString() ?? '';
          branch = addr.isNotEmpty ? addr : (b['name']?.toString() ?? 'N/A');
        }
      } catch (_) {}

      // Lịch học -> ngày, giờ, số buổi
      final List<dynamic> schedules = (clazz['classSchedules'] is List) ? clazz['classSchedules'] as List<dynamic> : <dynamic>[];
      final Set<String> daySet = {};
      String timeText = '';
      for (final s in schedules) {
        if (s is Map<String, dynamic>) {
          final dow = _tryParseInt(s['dayOfWeek'] ?? s['day_of_week'] ?? s['day']);
          if (dow != null && _weekdayNames.containsKey(dow)) daySet.add(_weekdayNames[dow]!);

          dynamic lessonSlot = s['lessonSlot'] ?? s['lesson_slot'] ?? s['lesson'];
          if (lessonSlot is Map) {
            final st = lessonSlot['startTime'] ?? lessonSlot['start_time'] ?? '';
            final et = lessonSlot['endTime'] ?? lessonSlot['end_time'] ?? '';
            if ((st?.toString().isNotEmpty ?? false) && (et?.toString().isNotEmpty ?? false)) {
              if (timeText.isEmpty) timeText = '${_formatTimeValue(st)} - ${_formatTimeValue(et)}';
            }
          } else {
            final st = s['startTime'] ?? s['start_time'] ?? s['time'];
            final et = s['endTime'] ?? s['end_time'];
            if ((st?.toString().isNotEmpty ?? false) && (et?.toString().isNotEmpty ?? false)) {
              if (timeText.isEmpty) timeText = '${_formatTimeValue(st)} - ${_formatTimeValue(et)}';
            }
          }
        }
      }
      final String days = daySet.isEmpty ? 'N/A' : daySet.join(', ');
      final int sessions = schedules.isNotEmpty ? schedules.length : (clazz['durationWeeks'] is int ? clazz['durationWeeks'] as int : 0);

      final dynamic feeRaw = clazz['fee'] ?? clazz['price'] ?? clazz['feeAmount'];
      String price = 'Liên hệ';
      try {
        if (feeRaw != null) {
          final num? f = (feeRaw is num) ? feeRaw : num.tryParse(feeRaw.toString());
          if (f != null) price = '${_decimal.format(f)} VND';
        }
      } catch (_) {}

      return {
        'id': classId ?? 0,
        'title': title,
        'description': description,
        'branch': branch,
        'days': days,
        'time': timeText.isEmpty ? 'N/A' : timeText,
        'sessions': sessions,
        'price': price,
        'feeRaw': feeRaw,
        'raw': clazz,
      };
    }).toList();

    _filteredCourses = List.from(_allCourses);
  }

  /// Trích xuất các tùy chọn bộ lọc từ dữ liệu khóa học.
  void _extractFilterOptions() {
    final subjectSet = <String>{};
    final gradeSet = <String>{};
    final timeSet = <String>{};
    final branchSet = <String>{};

    for (var course in _allCourses) {
      final raw = course['raw'] as Map<String, dynamic>?;

      try {
        final subject = raw?['subject'] is Map ? raw!['subject']['name']?.toString() ?? '' : '';
        if (subject.isNotEmpty) subjectSet.add(subject);
      } catch (_) {}

      try {
        final grade = raw?['grade'] is Map ? raw!['grade']['name']?.toString() ?? '' : '';
        if (grade.isNotEmpty) gradeSet.add(grade);
      } catch (_) {}

      final time = course['time'] as String? ?? '';
      if (time.isNotEmpty && time != 'N/A') timeSet.add(time);

      final branch = course['branch'] as String? ?? '';
      if (branch.isNotEmpty && branch != 'N/A') branchSet.add(branch);
    }

    setState(() {
      _subjects = subjectSet.toList()..sort();
      _grades = gradeSet.toList()..sort();
      _times = timeSet.toList()..sort();
      _branches = branchSet.toList()..sort();
    });
  }

  /// Áp dụng các bộ lọc đã chọn.
  void _applyFilters() {
    List<Map<String, dynamic>> results = _allCourses;

    if (_selectedSubject != null) {
      results = results.where((course) {
        final raw = course['raw'] as Map<String, dynamic>?;
        final subject = (raw != null && raw['subject'] is Map) ? raw['subject']['name']?.toString() ?? '' : '';
        return subject.contains(_selectedSubject!);
      }).toList();
    }

    if (_selectedGrade != null) {
      results = results.where((course) {
        final raw = course['raw'] as Map<String, dynamic>?;
        final grade = (raw != null && raw['grade'] is Map) ? raw['grade']['name']?.toString() ?? '' : '';
        return grade.contains(_selectedGrade!);
      }).toList();
    }

    if (_selectedTime != null) {
      results = results.where((course) => course['time'] == _selectedTime).toList();
    }

    if (_selectedBranch != null) {
      results = results.where((course) => course['branch'] == _selectedBranch).toList();
    }

    setState(() {
      _filteredCourses = results;
    });
  }

  /// Đặt lại tất cả bộ lọc về mặc định.
  void _resetFilters() {
    setState(() {
      _selectedSubject = null;
      _selectedGrade = null;
      _selectedTime = null;
      _selectedBranch = null;
      _filteredCourses = _allCourses;
    });
  }

  int? _tryParseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Widget hiển thị dropdown có nhãn.
  Widget _buildLabeledDropdown({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                hint: Text(hint),
                onChanged: onChanged,
                items: [
                  DropdownMenuItem<String>(value: null, child: Text(hint, style: const TextStyle(color: Colors.grey))),
                  ...items.map((String item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(item, overflow: TextOverflow.ellipsis, maxLines: 1),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị thẻ thông tin khóa học.
  Widget _buildCourseCard(Map<String, dynamic> course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(course['title'] ?? 'N/A', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(course['description'] ?? '', style: TextStyle(color: Colors.grey.shade700)),
            const Divider(height: 24),
            _buildDetailRow(Icons.location_on_outlined, course['branch'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.calendar_today_outlined, course['days'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.access_time_outlined, course['time'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.class_outlined, '${course['sessions'] ?? 0} buổi'),
            const SizedBox(height: 16),
            Text(
              course['price'] ?? 'Liên hệ',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị một dòng chi tiết với icon.
  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade800),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cửa hàng khóa học'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabeledDropdown(
                            label: 'Môn học',
                            value: _selectedSubject,
                            hint: 'Tất cả',
                            items: _subjects,
                            onChanged: (val) {
                              setState(() => _selectedSubject = val);
                              _applyFilters();
                            },
                          ),
                          const SizedBox(width: 12),
                          _buildLabeledDropdown(
                            label: 'Khối lớp',
                            value: _selectedGrade,
                            hint: 'Tất cả',
                            items: _grades,
                            onChanged: (val) {
                              setState(() => _selectedGrade = val);
                              _applyFilters();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabeledDropdown(
                            label: 'Chi nhánh',
                            value: _selectedBranch,
                            hint: 'Tất cả',
                            items: _branches,
                            onChanged: (val) {
                              setState(() => _selectedBranch = val);
                              _applyFilters();
                            },
                          ),
                          const SizedBox(width: 12),
                          _buildLabeledDropdown(
                            label: 'Khung giờ',
                            value: _selectedTime,
                            hint: 'Tất cả',
                            items: _times,
                            onChanged: (val) {
                              setState(() => _selectedTime = val);
                              _applyFilters();
                            },
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Xóa bộ lọc'),
                          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredCourses.isEmpty
                      ? const Center(child: Text('Không tìm thấy khóa học nào phù hợp.', style: TextStyle(fontSize: 16, color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _filteredCourses.length,
                          itemBuilder: (context, index) {
                            return _buildCourseCard(_filteredCourses[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}