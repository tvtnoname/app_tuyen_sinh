import 'dart:async';
import 'dart:convert';
import 'package:app_quan_ly_tuyen_sinh/screens/student/StudentNotificationScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/services/student/student_service.dart';
import 'package:app_quan_ly_tuyen_sinh/services/student/registered_courses_service.dart';
import 'package:app_quan_ly_tuyen_sinh/services/auth/auth_service.dart';
import 'package:flutter/services.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/student/CourseStoreScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/student/RegisteredCoursesScreen.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import 'package:http/http.dart' as http;

class Home extends StatefulWidget {
  final User user;
  const Home({super.key, required this.user});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  final StudentService _studentService = StudentService();
  final RegisteredCoursesService _registeredService = RegisteredCoursesService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _registeredCourses = [];
  int _unreadNotifications = 0;
  Timer? _notificationTimer;

  // Dữ liệu buổi học tiếp theo cần hiển thị

  Map<String, dynamic>? _nextSession;
  bool _isLoadingNextSession = false;

  // Trạng thái hiển thị biểu đồ

  Map<String, dynamic>? _selectedCourseForChart;

  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    await Future.wait([
      _loadRegisteredCourses(),
      _loadNotifications(),
    ]);
    // Tính toán buổi học tiếp theo sau khi tải danh sách khóa học

    await _loadNextSession();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> reload() async {
    await _loadAllData();
  }

  Future<void> _loadRegisteredCourses() async {
    try {
      final list = await _registeredService.getCourses();
      if (mounted) {
        setState(() {
          _registeredCourses = list;
          // Đặt lại lựa chọn nếu danh sách không rỗng, hoặc nếu lựa chọn hiện tại không hợp lệ

          if (_registeredCourses.isNotEmpty) {
             _selectedCourseForChart = _registeredCourses.first;
          } else {
             _selectedCourseForChart = null;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading registered courses: $e");
      // Dự phòng: xử lý lỗi tải dữ liệu


    }
  }

  Future<void> _loadNotifications() async {
    try {
      final allNotifs = await _studentService.getNotifications();
      // Lọc theo receiverId == widget.user.id VÀ loại bỏ PAYMENT

      final myNotifs = allNotifs.where((n) {
        final rid = n['receiverId'] ?? n['receiver_id'];
        bool isForMe = false;
        if (rid is int) isForMe = rid == widget.user.id;
        if (rid is String) isForMe = int.tryParse(rid) == widget.user.id;
        
        // Lọc bỏ PAYMENT notifications
        final notifType = (n['notificationType'] ?? n['notification_type'] ?? '').toString().toUpperCase();
        bool isNotPayment = notifType != 'PAYMENT';
        
        return isForMe && isNotPayment;
      }).toList();

      final unreadCount = myNotifs.where((notif) {
        final rawIsRead = notif['isRead'] ?? notif['is_read'];
        final isRead = rawIsRead == 1 || rawIsRead == true || rawIsRead == '1';
        return !isRead;
      }).length;

      if (mounted) {
        setState(() {
          _notifications = myNotifs;
          _unreadNotifications = unreadCount;
        });
      }
    } catch (e) {
      debugPrint("Error loading notifications: $e");
    }
  }

  Future<void> _loadNextSession() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNextSession = true;
      _nextSession = null;
    });

    try {
      final now = DateTime.now();
      DateTime? bestDateTime;
      Map<String, dynamic>? bestInfo;

      // Với mỗi khóa học đã đăng ký, lấy classId và chi tiết lớp học để tính toán buổi học tiếp theo


      for (final rc in _registeredCourses) {
        final dynamic cidRaw = rc['classId'] ?? rc['raw']?['classId'] ?? rc['raw']?['clazz']?['classId'];
        final int? classId = (cidRaw is int) ? cidRaw : (cidRaw != null ? int.tryParse(cidRaw.toString()) : null);
        if (classId == null) continue;

        final Map<String, dynamic>? clazz = await _fetchClassById(classId);
        if (clazz == null) continue;

        // Tính toán thời gian buổi học tiếp theo cho lớp này và chọn thời gian sớm nhất


        final candidate = _nextSessionForClazz(clazz, now);
        if (candidate != null) {
          final dt = candidate['dateTime'] as DateTime;
          if (bestDateTime == null || dt.isBefore(bestDateTime)) {
            bestDateTime = dt;
            bestInfo = {
              'classId': classId,
              'className': clazz['name'] ?? clazz['code'] ?? rc['subject'] ?? 'Khóa học',
              'dateTime': dt,
              'branch': (clazz['branch'] is Map) ? (clazz['branch']['address'] ?? clazz['branch']['name']) : (clazz['branch'] ?? ''),
              'timeLabel': candidate['timeLabel'],
              'rawClazz': clazz,
            };
          }
        }
      }

      if (mounted) {
        setState(() {
          _nextSession = bestInfo;
          _isLoadingNextSession = false;
        });
      }
    } catch (e) {
      debugPrint('Error computing next session: $e');
      if (mounted) setState(() {
        _isLoadingNextSession = false;
        _nextSession = null;
      });
    }
  }

  // Lấy thông tin chi tiết lớp học từ API


  Future<Map<String, dynamic>?> _fetchClassById(int id) async {
    try {
      String apiBase = _auth_service_baseUrl();
      if (apiBase.endsWith('/api/auth')) {
        apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
      }
      final uri = Uri.parse('$apiBase/api/home/class/$id');
      final token = await _authService.getToken();
      final headers = <String, String>{ 'Accept': 'application/json', 'Content-Type': 'application/json' };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body);
        if (body.containsKey('data') && body['data'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(body['data'] as Map<String, dynamic>);
        } else {
          return Map<String, dynamic>.from(body);
        }
      } else {
        debugPrint('fetchClassById status ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('fetchClassById error: $e');
    }
    return null;
  }

  String _auth_service_baseUrl() {
    var apiBase = _authService.baseUrl;
    return apiBase;
  }

  // Tính toán thời gian buổi học tiếp theo dựa trên lịch học của lớp


  Map<String, dynamic>? _nextSessionForClazz(Map<String, dynamic> clazz, DateTime from) {
    try {
      // Chuyển đổi ngày bắt đầu/kết thúc sang giờ địa phương


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

      // Danh sách lịch học


      final schedules = (clazz['classSchedules'] is List) ? List.from(clazz['classSchedules'] as List) : (clazz['schedules'] is List ? List.from(clazz['schedules'] as List) : []);
      if (schedules.isEmpty) return null;

      DateTime now = from;

      DateTime? best;
      String? bestTimeLabel;

      for (final s in schedules) {
        if (s is! Map) continue;
        final int? dow = _tryParseInt(s['dayOfWeek'] ?? s['day_of_week'] ?? s['day']);
        if (dow == null) continue;

        // Xác định thời gian bắt đầu và kết thúc


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

        // Tìm ngày học tiếp theo trong tuần


        DateTime candidateDate = _nextDateForWeekdayFrom(now, dow);

        // Điều chỉnh ngày học nếu trước ngày bắt đầu lớp


        if (classStart != null && candidateDate.isBefore(classStart)) {
          candidateDate = _firstWeekdayOnOrAfter(classStart, dow);
        }

        // Kết hợp ngày và giờ


        final timeParts = stStr.split(':');
        int hour = 0;
        int minute = 0;
        if (timeParts.length >= 2) {
          hour = int.tryParse(timeParts[0]) ?? 0;
          minute = int.tryParse(timeParts[1]) ?? 0;
        } else {
          final h = int.tryParse(stStr) ?? 0;
          hour = h;
        }
        DateTime candidateDateTime = DateTime(candidateDate.year, candidateDate.month, candidateDate.day, hour, minute);

        // Chuyển sang tuần kế tiếp nếu thời gian đã qua


        if (candidateDateTime.isBefore(now)) {
          candidateDateTime = candidateDateTime.add(const Duration(days: 7));
        }

        // Kiểm tra thời gian có nằm trong thời hạn lớp học không


        if (classEnd != null) {
          final lastValid = DateTime(classEnd.year, classEnd.month, classEnd.day, 23, 59, 59);
          if (candidateDateTime.isAfter(lastValid)) {
            continue; // Bỏ qua lịch này

          }
        }

        // Cập nhật thời gian học sớm nhất tìm được


        if (best == null || candidateDateTime.isBefore(best)) {
          best = candidateDateTime;
          final etLabel = etStr.isNotEmpty ? ' - ${_formatTimeValue(etStr)}' : '';
          bestTimeLabel = '${_formatTimeValue(stStr)}$etLabel';
        }
      }

      if (best != null) {
        return {'dateTime': best, 'timeLabel': bestTimeLabel ?? ''};
      }
    } catch (e) {
      debugPrint('Error in _nextSessionForClazz: $e');
    }
    return null;
  }

  // Helper: Tìm ngày tiếp theo của thứ trong tuần


  DateTime _nextDateForWeekdayFrom(DateTime from, int weekday) {
    // Lưu ý: Dart weekday (Thứ 2 = 1 ... Chủ nhật = 7)


    int offset = (weekday - from.weekday) % 7;
    if (offset < 0) offset += 7;
    return DateTime(from.year, from.month, from.day).add(Duration(days: offset));
  }

  // Helper: Tìm ngày đầu tiên của thứ trong tuần từ mốc thời gian


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

  Future<void> _navigateToScreen(Widget screen) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    if (result == true) {
      _loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isParent = (widget.user.role ?? '').toUpperCase() == 'PARENT';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, widget.user),
              const SizedBox(height: 24),
              isParent ? _buildApprovalCard(context) : _buildPrimaryActionCard(context),
              const SizedBox(height: 24),
              _buildRegisteredCoursesCard(context),
              const SizedBox(height: 24),
              _buildUpcomingSessionCard(), // unchanged layout but populated by API
              const SizedBox(height: 24),
              _buildProgressCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User user) {
    final displayName = user.fullName ?? 'bạn';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Chào mừng trở lại,',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () => _navigateToScreen(StudentNotificationScreen(studentId: widget.user.id ?? 0)),
                icon: const Icon(Icons.notifications_outlined, size: 30, color: Colors.black54),
                tooltip: 'Thông báo',
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadNotifications.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisteredCoursesCard(BuildContext context) {
    final pendingCount = _registeredCourses.where((c) => c['status'] == 'Chờ xác nhận').length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.class_, color: Colors.blueAccent),
        title: const Text('Các khoá học của tôi', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Xem lại thông tin và trạng thái các khoá học'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  pendingCount.toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios),
          ],
        ),
        onTap: () => _navigateToScreen(RegisteredCoursesScreen(registeredCourses: _registeredCourses, user: widget.user.toJson())),
      ),
    );
  }

  Widget _buildPrimaryActionCard(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.store, size: 48, color: Colors.blue),
            const SizedBox(height: 12),
            const Text(
              'Khám phá hàng trăm khóa học chất lượng cao',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _navigateToScreen(const CourseStoreScreen()),
              icon: const Icon(Icons.search, color: Colors.white),
              label: const Text('Xem cửa hàng', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalCard(BuildContext context) {
    final pendingCount = _registeredCourses.where((c) => c['status'] == 'Chờ xác nhận').length;

    return Card(
      color: Colors.orange.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            const Text(
              'Khoá học cần xác nhận',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn có $pendingCount khoá học đang chờ được duyệt.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _navigateToScreen(RegisteredCoursesScreen(registeredCourses: _registeredCourses, user: widget.user.toJson())),
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              label: const Text('Xem ngay', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSessionCard() {
    // Xây dựng giao diện hiển thị buổi học tiếp theo


    Widget content;
    if (_isLoadingNextSession) {
      content = const ListTile(
        leading: Icon(Icons.access_time, color: Colors.green),
        title: Text('Buổi học tiếp theo', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(padding: EdgeInsets.only(top: 8.0), child: Text('Đang tải...')),
      );
    } else if (_nextSession == null) {
      content = const ListTile(
        leading: Icon(Icons.access_time, color: Colors.green),
        title: Text('Buổi học tiếp theo', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Chưa có buổi học tiếp theo'),
      );
    } else {
      final dt = _nextSession!['dateTime'] as DateTime;
      final dateLabel = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      final timeLabel = _nextSession!['timeLabel']?.toString() ?? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      final className = _nextSession!['className']?.toString() ?? 'Buổi học';
      final branch = _nextSession!['branch']?.toString() ?? '';

      content = ListTile(
        leading: const Icon(Icons.access_time, color: Colors.green),
        title: Text(className, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$dateLabel lúc $timeLabel\n$branch'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {},
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: content,
    );
  }

  Widget _buildProgressCard() {
    if (_registeredCourses.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kết quả học tập',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                if (_registeredCourses.isNotEmpty)
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        isExpanded: true,
                        value: _selectedCourseForChart,
                        hint: const Text('Chọn khóa học', overflow: TextOverflow.ellipsis),
                        isDense: true,
                        itemHeight: null, // Allow variable height for wrapped text
                        alignment: AlignmentDirectional.centerEnd,
                        items: _registeredCourses.map((course) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: course,
                            child: Text(
                              (course['subject'] ?? 'Khóa học') +
                                  (course['semester'] is Map && course['semester']['name'] != null
                                      ? ' - ${course['semester']['name']}'
                                      : ''),
                              // Remove overflow: TextOverflow.ellipsis to allow wrapping
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCourseForChart = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedCourseForChart != null)
              _buildBarChart(_selectedCourseForChart!)
            else
              const Center(child: Text('Vui lòng chọn khóa học để xem điểm')),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, dynamic> course) {
    // Trích xuất dữ liệu điểm số


    double s1 = _parseScore(course['score_1']);
    double s2 = _parseScore(course['score_2']);
    double s3 = _parseScore(course['score_3']);
    double finalScore = _parseScore(course['final_score'] ?? course['grade']);

    // Giới hạn điểm tối đa là 10


    const double maxScore = 10.0;

    return SizedBox(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBarColumn('Điểm 1', s1, maxScore, Colors.blueAccent),
          _buildBarColumn('Điểm 2', s2, maxScore, Colors.orangeAccent),
          _buildBarColumn('Điểm 3', s3, maxScore, Colors.purpleAccent),
          _buildBarColumn('Điểm trung bình', finalScore, maxScore, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildBarColumn(String label, double score, double max, Color color) {
    // Xử lý hiển thị cột điểm khi giá trị là 0

    // Tính toán tỷ lệ chiều cao cột

    final double percentage = (score / max).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          score > 0 ? score.toString() : 'Chưa có',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          width: 20,
          height: 140 * percentage, // Max height 140
          decoration: BoxDecoration(
            color: score > 0 ? color : Colors.grey.shade300,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  double _parseScore(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }
}