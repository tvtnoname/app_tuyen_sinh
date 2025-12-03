import 'dart:convert';
import 'package:app_quan_ly_tuyen_sinh/screens/common/PaymentScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/services/student/registered_courses_service.dart';
import 'package:app_quan_ly_tuyen_sinh/services/auth/auth_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class RegisteredCoursesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> registeredCourses;
  final Map<String, dynamic> user;

  const RegisteredCoursesScreen({super.key, required this.registeredCourses, required this.user});

  @override
  State<RegisteredCoursesScreen> createState() => _RegisteredCoursesScreenState();
}

class _RegisteredCoursesScreenState extends State<RegisteredCoursesScreen> {
  List<Map<String, dynamic>> _allCourses = [];
  final RegisteredCoursesService _coursesService = RegisteredCoursesService();
  final AuthService _authService = AuthService();
  int? _selectedSemesterId;

  @override
  void initState() {
    super.initState();
    _allCourses = widget.registeredCourses;
    _refreshFromApi();
  }

  Future<void> _refreshFromApi() async {
    try {
      final list = await _coursesService.getCourses();
      if (mounted && list.isNotEmpty) {
        setState(() {
          _allCourses = list;
        });
      }
    } catch (e) {
      debugPrint('Failed to refresh registered courses from API: $e');
    }
  }

  /// Cập nhật trạng thái khóa học và lưu (local + API nếu có).
  Future<void> _updateCourseStatus(String subject, String newStatus) async {
    final idx = _allCourses.indexWhere((c) => c['subject'] == subject);
    if (idx != -1) {
      setState(() {
        _allCourses[idx]['status'] = newStatus;
      });
    }
  }

  bool _isCourseActive(Map<String, dynamic> course) {
    var endDateStr = course['endDate']?.toString();
    debugPrint('DEBUG: _isCourseActive check for ${course['subject']}');
    debugPrint('DEBUG: Raw endDateStr: "$endDateStr"');

    if (endDateStr == null || endDateStr.isEmpty) {
      debugPrint('DEBUG: endDateStr is null/empty -> Active');
      return true;
    }

    endDateStr = endDateStr.trim();
    try {
      DateTime? endDate;
      try {
        endDate = DateTime.parse(endDateStr);
      } catch (_) {
        try {
          endDate = DateFormat('dd/MM/yyyy').parse(endDateStr);
        } catch (_) {
           try {
             endDate = DateFormat('dd-MM-yyyy').parse(endDateStr);
           } catch (_) {}
        }
      }

      if (endDate == null) {
        debugPrint('DEBUG: Parse failed -> Active');
        return true;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      
      final isBefore = end.isBefore(today);
      debugPrint('DEBUG: Parsed EndDate: $end, Today: $today, isBefore: $isBefore');

      // Nếu ngày kết thúc nhỏ hơn ngày hiện tại -> Đã kết thúc
      return !isBefore;
    } catch (e) {
      debugPrint('DEBUG: Exception: $e');
      return true;
    }
  }

  List<Map<String, dynamic>> _getAvailableSemesters(List<Map<String, dynamic>> courses) {
    final Map<int, String> semesters = {};
    for (var course in courses) {
      if (course['semester'] is Map) {
        final id = course['semester']['id'];
        final name = course['semester']['name'];
        if (id != null && name != null) {
          semesters[id] = name;
        }
      }
    }
    return semesters.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Tách các khóa học chờ xác nhận (luôn hiển thị trên cùng)
    final pendingCourses = _allCourses.where((c) => c['status'] == 'Chờ xác nhận').toList();
    
    // 2. Các khóa học còn lại (đã duyệt, từ chối, v.v...)
    final otherCourses = _allCourses.where((c) => c['status'] != 'Chờ xác nhận').toList();

    // 3. Phân loại Hiện tại vs Đã học dựa trên endDate
    final activeCourses = otherCourses.where((c) => _isCourseActive(c)).toList();
    final endedCourses = otherCourses.where((c) => !_isCourseActive(c)).toList();

    // 4. Lọc khóa học đã học theo học kỳ
    final filteredEndedCourses = _selectedSemesterId == null
        ? endedCourses
        : endedCourses.where((c) => c['semester'] is Map && c['semester']['id'] == _selectedSemesterId).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Các khoá học đã đăng ký'),
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'Đang học'),
              Tab(text: 'Đã học'),
            ],
          ),
        ),
        backgroundColor: Colors.grey[50],
        body: RefreshIndicator(
          onRefresh: _refreshFromApi,
          child: TabBarView(
            children: [
              // Tab 1: Đang học (Chờ xác nhận + Đang học)
              ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  if (pendingCourses.isEmpty && activeCourses.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.only(top: 50), child: Text('Không có khóa học nào đang học'))),
                  
                  // Mục Chờ xác nhận
                  if (pendingCourses.isNotEmpty)
                    _buildCourseStatusSection(
                      context: context,
                      title: 'CHỜ XÁC NHẬN',
                      courses: pendingCourses,
                      notificationCount: pendingCourses.length,
                      isPendingSection: true,
                    ),

                  // Mục Khóa học hiện tại
                  if (activeCourses.isNotEmpty)
                    _buildCourseStatusSection(
                      context: context,
                      title: 'KHÓA HỌC HIỆN TẠI',
                      courses: activeCourses,
                    ),
                ],
              ),

              // Tab 2: Đã học (có bộ lọc)
              Column(
                children: [
                   // Filter Bar
                   if (endedCourses.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey[50],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Lọc theo học kỳ:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isDense: true,
                                hint: const Text('Tất cả', style: TextStyle(fontSize: 13)),
                                value: _selectedSemesterId,
                                items: [
                                  const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text('Tất cả', style: TextStyle(fontSize: 13)),
                                  ),
                                  ..._getAvailableSemesters(endedCourses).map((sem) {
                                    return DropdownMenuItem<int>(
                                      value: sem['id'],
                                      child: Text(sem['name'], style: const TextStyle(fontSize: 13)),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSemesterId = val;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        if (filteredEndedCourses.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.only(top: 50), child: Text('Không có khóa học nào'))),
                        ...filteredEndedCourses.map((course) => _buildCourseStatusCard(context, course)).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseStatusSection({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> courses,
    int notificationCount = 0,
    bool isPendingSection = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isPendingSection ? Colors.orange[800] : Colors.black87)),
            const SizedBox(width: 8),
            if (notificationCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                child: Text(notificationCount.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...courses.map((course) => _buildCourseStatusCard(context, course)).toList(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ... (existing code)

  Widget _buildCourseStatusCard(BuildContext context, Map<String, dynamic> course) {
    final status = course['status'] ?? '';
    final isPending = status == 'Chờ xác nhận';
    
    final role = widget.user['role']?.toString().toUpperCase() ?? '';
    final isParent = role == 'PARENT' || role == 'PHỤ HUYNH';

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'Chờ xác nhận':
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'Đã từ chối':
        statusColor = Colors.red.shade700;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle_rounded;
    }

    // Tạo tên hiển thị: Tên môn - Học kỳ
    String displayName = course['subject']?.toString() ?? 'Khóa học';
    // Debug semester data
    debugPrint('DEBUG: Course: $displayName, Semester: ${course['semester']}');

    return GestureDetector(
      onTap: () {
        if (isParent && isPending) {
          _showApprovalSheet(context, course);
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text('Ngày đăng ký: ${course['registrationDate'] ?? ''}'),
              ]),
              // Luôn hiển thị ngày kết thúc nếu có
              if (course['endDate'] != null && course['endDate'].toString().isNotEmpty) ...[
                 const SizedBox(height: 4),
                 Row(children: [
                  Icon(Icons.event_busy, size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Text('Kết thúc: ${course['endDate']}', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w500)),
                ]),
              ],
              // Hiển thị học kỳ
              if (course['semester'] is Map && course['semester']['name'] != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.school, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${course['semester']['name']}',
                      style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Text('Trạng thái: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
              ]),
              if (isParent && isPending)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('Nhấn để xem chi tiết & duyệt', style: TextStyle(color: Colors.blue, fontStyle: FontStyle.italic)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApprovalSheet(BuildContext context, Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ApprovalSheet(course: course, onDecline: () {
        _updateCourseStatus(course['subject'], 'Đã từ chối');
        Navigator.of(ctx).pop(); // Đóng bottom sheet
      }),
    ).then((_) {
      // Tùy chọn làm mới lại dữ liệu
      _refreshFromApi();
    });
  }
}

class ApprovalSheet extends StatefulWidget {
  final Map<String, dynamic> course;
  final VoidCallback onDecline;

  const ApprovalSheet({super.key, required this.course, required this.onDecline});

  @override
  State<ApprovalSheet> createState() => _ApprovalSheetState();
}

class _ApprovalSheetState extends State<ApprovalSheet> {
  Map<String, dynamic>? _fullCourseDetails;
  bool _isLoading = true;
  String? _selectedDuration;
  String? _selectedMethod;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadFullCourseDetails();
  }

  Future<void> _loadFullCourseDetails() async {
    setState(() { _isLoading = true; });
    try {
      // Ưu tiên lấy classId từ khóa học
      final dynamic cid = widget.course['classId'] ?? widget.course['raw']?['classId'] ?? widget.course['raw']?['clazz']?['classId'];
      final int? classId = cid is int ? cid : (cid != null ? int.tryParse(cid.toString()) : null);

      if (classId != null) {
        // Gọi GET /api/home/class/{id}

        String apiBase = _authService.baseUrl;
        if (apiBase.endsWith('/api/auth')) {
          apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
        }
        final uri = Uri.parse('$apiBase/api/home/class/$classId');
        final token = await _auth_service_getToken();
        final headers = <String, String>{ 'Accept': 'application/json', 'Content-Type': 'application/json' };
        if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
        final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final Map<String, dynamic> body = jsonDecode(resp.body);
          Map<String, dynamic>? data;
          if (body.containsKey('data') && body['data'] is Map) data = Map<String, dynamic>.from(body['data']);
          else data = Map<String, dynamic>.from(body);
          if (mounted) setState(() { _fullCourseDetails = data; _isLoading = false; });
          return;
        } else {
          debugPrint('ApprovalSheet: fetch class $classId failed ${resp.statusCode}');
        }
      }

      // Fallback: sử dụng dữ liệu thô (raw) hoặc các trường từ widget.course

      setState(() {
        _fullCourseDetails = widget.course['raw'] is Map ? Map<String, dynamic>.from(widget.course['raw']) : Map<String, dynamic>.from(widget.course);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ApprovalSheet.loadFullCourseDetails error: $e');
      if (mounted) setState(() { _isLoading = false; _fullCourseDetails = widget.course['raw'] is Map ? Map<String, dynamic>.from(widget.course['raw']) : Map<String, dynamic>.from(widget.course); });
    }
  }

  // Helper nhỏ để lấy auth token (tách riêng để dễ testing/mocking)
  Future<String?> _auth_service_getToken() => _auth_service_token();

  Future<String?> _auth_service_token() async {
    try {
      return await _auth_service_getToken_real();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _auth_service_getToken_real() async {
    return await _authService.getToken();
  }

  String _formatPrice(double price) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ').format(price);
  }

  void _handleApproval() {
    if (_fullCourseDetails == null || _selectedDuration == null || _selectedMethod == null) return;

    final priceString = (_fullCourseDetails!['fee']?.toString() ?? _fullCourseDetails!['price']?.toString() ?? '0').replaceAll(RegExp(r'[^0-9]'), '');
    final fullPrice = double.tryParse(priceString) ?? 0;
    final pricePerMonth = fullPrice / 3;

    final paymentDurations = {
      'Thanh toán cả khoá (3 tháng)': fullPrice,
      'Thanh toán 2 tháng': pricePerMonth * 2,
      'Thanh toán 1 tháng': pricePerMonth,
    };

    final amountToPay = paymentDurations[_selectedDuration]!;

    Navigator.of(context).pop(); // Đóng bottom sheet

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          courseDetails: _fullCourseDetails!,
          selectedDuration: _selectedDuration!,
          amount: amountToPay,
          paymentMethod: _selectedMethod!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator()));
    }
    if (_fullCourseDetails == null) {
      return const Padding(padding: EdgeInsets.all(32.0), child: Center(child: Text('Không tìm thấy chi tiết khóa học.')));
    }

    final priceString = (_fullCourseDetails!['fee']?.toString() ?? _fullCourseDetails!['price']?.toString() ?? '0').replaceAll(RegExp(r'[^0-9]'), '');
    final fullPrice = double.tryParse(priceString) ?? 0;
    final pricePerMonth = fullPrice / 3;

    final paymentDurations = {
      'Thanh toán cả khoá (3 tháng)': fullPrice,
      'Thanh toán 2 tháng': pricePerMonth * 2,
      'Thanh toán 1 tháng': pricePerMonth,
    };
    _selectedDuration ??= paymentDurations.keys.first;

    final paymentMethods = ['Thanh toán qua ngân hàng', 'Thanh toán tại trung tâm'];
    _selectedMethod ??= paymentMethods.first;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Xác nhận đăng ký', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 24),
          _buildDetailRow(Icons.book_outlined, "Khóa học", _fullCourseDetails!['name'] ?? _fullCourseDetails!['title'] ?? widget.course['subject'] ?? 'N/A'),
          _buildDetailRow(Icons.location_on_outlined, "Chi nhánh", _fullCourseDetails!['branch']?['address']?.toString() ?? _fullCourseDetails!['branch']?.toString() ?? 'N/A'),
          _buildDetailRow(Icons.calendar_today_outlined, "Lịch học", _fullCourseDetails!['classSchedules'] != null ? (_fullCourseDetails!['classSchedules'] as List).map((s) => (s['dayOfWeek']?.toString() ?? '')).join(', ') : ( _fullCourseDetails!['days'] ?? 'N/A' )),
          _buildDetailRow(Icons.access_time_outlined, "Khung giờ", _getRepresentativeTime(_fullCourseDetails!)),
          _buildDetailRow(Icons.class_outlined, "Số buổi", '${_getSessions(_fullCourseDetails!)} buổi'),
          _buildDetailRow(Icons.price_change_outlined, "Học phí gốc", _formatPrice(fullPrice)),
          const Divider(height: 24),
          const Text('Bạn có nhu cầu thanh toán:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ...paymentDurations.entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.key),
              value: entry.key,
              groupValue: _selectedDuration,
              onChanged: (value) => setState(() => _selectedDuration = value),
              secondary: Text(_formatPrice(entry.value), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            );
          }),
          const SizedBox(height: 16),
          const Text('Hình thức thanh toán:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ...paymentMethods.map((method) {
            return RadioListTile<String>(
              title: Text(method),
              value: method,
              groupValue: _selectedMethod,
              onChanged: (value) => setState(() => _selectedMethod = value),
            );
          }),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onDecline,
                  icon: const Icon(Icons.close),
                  label: const Text('Từ chối'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleApproval,
                  icon: const Icon(Icons.check),
                  label: const Text('Xác nhận'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRepresentativeTime(Map<String, dynamic> details) {
    // Tìm thời gian bắt đầu/kết thúc của buổi học đầu tiên và định dạng HH:mm - HH:mm

    final schedules = _asList(details['classSchedules']) ?? _asList(details['clazz']?['classSchedules']) ?? _asList(details['schedules']);
    if (schedules != null && schedules.isNotEmpty) {
      for (final s in schedules) {
        if (s is Map) {
          final lesson = _asMap(s['lessonSlot']) ?? _asMap(s['lesson']);
          if (lesson != null) {
            final st = lesson['startTime'] ?? lesson['start_time'];
            final et = lesson['endTime'] ?? lesson['end_time'];
            if (st != null && et != null) return '${_formatTimeValue(st)} - ${_formatTimeValue(et)}';
          }
        }
      }
    }
    // Fallback về details.time hoặc details['time']

    if (details['time'] != null) return details['time'].toString();
    return 'N/A';
  }

  int _getSessions(Map<String, dynamic> details) {
    final schedules = _asList(details['classSchedules']) ?? _asList(details['clazz']?['classSchedules']) ?? _asList(details['schedules']);
    if (schedules != null) return schedules.length;
    if (details['sessions'] != null) return (_tryParseInt(details['sessions']) ?? 0);
    return 0;
  }

  // Các hàm helper được sao chép để giữ file độc lập

  Map<String, dynamic>? _asMap(dynamic v) => (v is Map) ? Map<String, dynamic>.from(v) : null;
  List<dynamic>? _asList(dynamic v) => (v is List) ? v : null;
  String _formatTimeValue(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    final parts = s.split(':');
    if (parts.length >= 2) return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    return s;
  }

  // Thêm helper _buildDetailRow còn thiếu được sử dụng trong build()

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // Thêm helper _tryParseInt còn thiếu để tránh lỗi undefined method

  int? _tryParseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}