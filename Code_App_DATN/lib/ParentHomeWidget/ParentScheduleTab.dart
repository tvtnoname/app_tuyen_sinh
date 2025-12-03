import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/parent/parent_service.dart';
import '../screens/parent/ParentNotificationScreen.dart';

/// Màn hình lịch học dành cho Phụ huynh.
/// Cho phép xem lịch học của con theo tuần.
class ParentScheduleTab extends StatefulWidget {
  const ParentScheduleTab({super.key});

  @override
  State<ParentScheduleTab> createState() => ParentScheduleTabState();
}

class ParentScheduleTabState extends State<ParentScheduleTab> {
  final ParentService _parentService = ParentService();
  bool _isLoading = true;
  Timer? _notificationTimer;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _children = [];
  Map<String, dynamic>? _selectedChild;
  Map<String, List<Map<String, dynamic>>> _scheduleByDay = {};
  late DateTime _selectedDate;

  // Layout constants
  static const double _headerHeight = 60.0;
  static const double _sessionCellHeight = 220.0;
  static const double _sessionHeaderWidth = 60.0;
  static const double _dayColumnWidth = 220.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadChildren();
    _startNotificationTimer();
  }

  /// Khởi tạo timer để kiểm tra thông báo chưa đọc định kỳ.
  void _startNotificationTimer() {
    _fetchUnreadNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchUnreadNotifications();
    });
  }

  /// Lấy số lượng thông báo chưa đọc từ API.
  Future<void> _fetchUnreadNotifications() async {
    try {
      final notifs = await _parentService.getNotifications();
      
      // Count unread notifications where receiverType == "PARENT"
      final unreadCount = notifs.where((n) {
        final receiverType = (n['receiverType'] ?? n['receiver_type'] ?? '').toString().toUpperCase();
        final rawIsRead = n['isRead'] ?? n['is_read'];
        final isRead = rawIsRead == 1 || rawIsRead == true || rawIsRead == '1';
        
        return receiverType == 'PARENT' && !isRead;
      }).length;

      if (mounted) {
        setState(() => _unreadNotifications = unreadCount);
      }
    } catch (e) {
      // Error fetching unread notifications
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  /// Tải danh sách con em.
  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    try {
      final children = await _parentService.getChildren();
      if (mounted) {
        setState(() {
          _children = children;
          if (_children.isNotEmpty) {
            _selectedChild = _children.first;
            _loadStudentSchedule(_selectedChild!['studentId'] ?? _selectedChild!['id']);
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading children: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Tải lịch học của học sinh.
  Future<void> _loadStudentSchedule(int studentId) async {
    setState(() => _isLoading = true);
    try {
      final data = await _parentService.getStudentDetail(studentId);
      if (data != null) {
        debugPrint('ParentScheduleTab: Got data for student $studentId');
        _parseSchedule(data);
        
        // Update student name if available
        final detailName = data['user']?['fullName'] ?? data['fullName'] ?? data['name'];
        if (detailName != null && _selectedChild != null) {
           setState(() {
             _selectedChild!['fullName'] = detailName;
             // Also update in the list to ensure consistency
             final index = _children.indexWhere((c) => (c['studentId'] ?? c['id']) == studentId);
             if (index != -1) {
               _children[index]['fullName'] = detailName;
               // Also update the user object inside the child if it exists, for future reference
               if (_children[index]['user'] == null) {
                 _children[index]['user'] = {'fullName': detailName};
               } else {
                 _children[index]['user']['fullName'] = detailName;
               }
             }
           });
        }
      }
    } catch (e) {
      debugPrint('Error loading student schedule: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Tải lại dữ liệu (dùng cho tính năng kéo để làm mới).
  Future<void> reload() async {
    if (_selectedChild != null) {
      await _loadStudentSchedule(_selectedChild!['studentId'] ?? _selectedChild!['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang tải lại lịch học...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      await _loadChildren();
    }
  }

  /// Phân tích dữ liệu lịch học từ API và nhóm theo ngày.
  void _parseSchedule(Map<String, dynamic> data) {
    _scheduleByDay = {
      'Thứ 2': [], 'Thứ 3': [], 'Thứ 4': [], 'Thứ 5': [], 'Thứ 6': [], 'Thứ 7': [], 'Chủ Nhật': []
    };

    List<dynamic> studentClasses = [];
    if (data['studentClasses'] is List) {
      studentClasses = data['studentClasses'];
    } else if (data['classes'] is List) {
      studentClasses = data['classes'];
    }

    for (var sc in studentClasses) {
      if (sc is! Map) continue;
      final clazz = sc['clazz'];
      if (clazz is! Map) continue;

      final subject = clazz['subject'];
      final subjectName = subject is Map ? subject['name'] : 'Môn học';
      final className = clazz['name'] ?? clazz['code'] ?? 'Lớp học';
      
      // Parse class start/end dates
      DateTime? classStart;
      DateTime? classEnd;
      try {
        if (clazz['startDate'] != null) classStart = DateTime.tryParse(clazz['startDate']);
        if (clazz['endDate'] != null) classEnd = DateTime.tryParse(clazz['endDate']);
      } catch (_) {}

      final classSchedules = clazz['classSchedules'];

      if (classSchedules is List) {
        for (var s in classSchedules) {
          if (s is! Map) continue;

          final dayOfWeek = s['dayOfWeek'];
          String dayName = _getDayName(dayOfWeek);
          
          if (!_scheduleByDay.containsKey(dayName)) continue;

          final lessonSlot = s['lessonSlot'];
          final room = s['room'];

          _scheduleByDay[dayName]?.add({
            'className': className,
            'subject': subjectName,
            'startTime': lessonSlot is Map ? lessonSlot['startTime'] : '',
            'endTime': lessonSlot is Map ? lessonSlot['endTime'] : '',
            'room': room is Map ? room['name'] : '',
            'location': room is Map ? '${room['name']} - ${room['floor'] ?? ''}' : '',
            'classStart': classStart,
            'classEnd': classEnd,
          });
        }
      }
    }

    // Sort by start time
    _scheduleByDay.forEach((key, list) {
      list.sort((a, b) => (a['startTime'] ?? '').compareTo(b['startTime'] ?? ''));
    });
  }

  String _getDayName(dynamic dayOfWeek) {
    switch (dayOfWeek) {
      case 1: return 'Thứ 2';
      case 2: return 'Thứ 3';
      case 3: return 'Thứ 4';
      case 4: return 'Thứ 5';
      case 5: return 'Thứ 6';
      case 6: return 'Thứ 7';
      case 7: return 'Chủ Nhật';
      default: return 'Thứ ${dayOfWeek}';
    }
  }

  void _goToPreviousWeek() => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 7)));
  void _goToNextWeek() => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 7)));
  void _goToCurrentWeek() => setState(() => _selectedDate = DateTime.now());

  /// Chọn ngày cụ thể từ lịch.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Kiểm tra xem ngày hiện tại có nằm trong khoảng thời gian học của lớp không.
  bool _isDateWithinClassRange(DateTime dayDate, dynamic classStart, dynamic classEnd) {
    if (classStart == null && classEnd == null) return true;
    try {
      final DateTime? start = classStart is DateTime ? classStart : null;
      final DateTime? end = classEnd is DateTime ? classEnd : null;
      final normalizedDay = DateTime(dayDate.year, dayDate.month, dayDate.day);
      
      if (start != null && end != null) {
        final normalizedStart = DateTime(start.year, start.month, start.day);
        final normalizedEnd = DateTime(end.year, end.month, end.day);
        return !normalizedDay.isBefore(normalizedStart) && !normalizedDay.isAfter(normalizedEnd);
      } else if (start != null) {
        final normalizedStart = DateTime(start.year, start.month, start.day);
        return !normalizedDay.isBefore(normalizedStart);
      } else if (end != null) {
        final normalizedEnd = DateTime(end.year, end.month, end.day);
        return !normalizedDay.isAfter(normalizedEnd);
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: _children.isEmpty 
            ? const Text('Lịch học')
            : Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.blue.shade100, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: ButtonTheme(
                    alignedDropdown: true,
                    child: DropdownButton<Map<String, dynamic>>(
                      value: _selectedChild,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blue),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                      items: _children.map((child) {
                        return DropdownMenuItem(
                          value: child,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blue.shade50,
                                child: const Icon(Icons.face_rounded, size: 18, color: Colors.blue),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                child['user']?['fullName'] ?? child['fullName'] ?? child['name'] ?? 'Học sinh',
                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      selectedItemBuilder: (BuildContext context) {
                        return _children.map((child) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blue.shade50,
                                child: const Icon(Icons.face_rounded, size: 18, color: Colors.blue),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                child['user']?['fullName'] ?? child['fullName'] ?? child['name'] ?? 'Học sinh',
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        }).toList();
                      },
                      onChanged: (Map<String, dynamic>? newValue) {
                        if (newValue != null && newValue != _selectedChild) {
                          setState(() => _selectedChild = newValue);
                          _loadStudentSchedule(newValue['studentId'] ?? newValue['id']);
                        }
                      },
                    ),
                  ),
                ),
              ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  int? studentId;
                  if (_selectedChild != null) {
                    studentId = _selectedChild!['studentId'] ?? _selectedChild!['id'];
                  }
                  
                  if (studentId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParentNotificationScreen(studentId: studentId!),
                      ),
                    );
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng chọn học sinh trước')),
                    );
                  }
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
        child: Column(
          children: [
            _buildToolbar(),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _children.isEmpty
                      ? const Center(child: Text('Không có thông tin học sinh'))
                      : GestureDetector(
                          onDoubleTap: () {
                            if (_selectedChild != null) {
                              _loadStudentSchedule(_selectedChild!['studentId'] ?? _selectedChild!['id']);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đang tải lại lịch học...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          child: SingleChildScrollView(
                            child: _buildScheduleGrid(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị thanh công cụ điều hướng tuần.
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), spreadRadius: 1, blurRadius: 5)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 8),
            TextButton(onPressed: _goToPreviousWeek, child: const Text('Trở lại')),
            const SizedBox(height: 30, child: VerticalDivider(thickness: 1)),
            TextButton(onPressed: _goToNextWeek, child: const Text('Tiếp')),
            const SizedBox(height: 30, child: VerticalDivider(thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextButton(onPressed: _goToCurrentWeek, child: const Text('Hiện tại')),
            ),
            const SizedBox(height: 30, child: VerticalDivider(thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                style: TextButton.styleFrom(foregroundColor: Colors.black87),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị lưới lịch học.
  Widget _buildScheduleGrid() {
    final daysOfWeek = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'];
    // Calculate start of week (Monday)
    // Note: DateTime.weekday returns 1 for Monday, 7 for Sunday
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSessionHeaders(),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: daysOfWeek.asMap().entries.map((entry) {
                final dayName = entry.value;
                // entry.key 0 is Monday, which matches startOfWeek + 0 days
                final date = startOfWeek.add(Duration(days: entry.key));
                
                final events = (_scheduleByDay[dayName] ?? []).toList();
                
                return _buildDayColumn(dayName, date, events);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// Widget hiển thị tiêu đề các buổi (Sáng, Chiều, Tối).
  Widget _buildSessionHeaders() {
    return SizedBox(
      width: _sessionHeaderWidth,
      child: Column(
        children: [
          SizedBox(height: _headerHeight),
          _buildHeaderCell('Sáng'),
          _buildHeaderCell('Chiều'),
          _buildHeaderCell('Tối'),
        ],
      ),
    );
  }

  /// Widget hiển thị cột lịch học cho một ngày.
  Widget _buildDayColumn(String dayTitle, DateTime date, List<Map<String, dynamic>> events) {
    final filteredEvents = events.where((e) {
      return _isDateWithinClassRange(date, e['classStart'], e['classEnd']);
    }).toList();
    
    final morningEvents = filteredEvents.where((e) {
      final time = e['startTime'] as String?;
      if (time == null) return false;
      return time.compareTo('13:30') < 0;
    }).toList();

    final afternoonEvents = filteredEvents.where((e) {
      final time = e['startTime'] as String?;
      if (time == null) return false;
      return time.compareTo('13:30') >= 0 && time.compareTo('17:30') < 0;
    }).toList();

    final eveningEvents = filteredEvents.where((e) {
      final time = e['startTime'] as String?;
      if (time == null) return false;
      return time.compareTo('17:30') >= 0;
    }).toList();

    return Container(
      width: _dayColumnWidth,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Column(
        children: [
          _buildDateHeaderCell(dayTitle, date),
          _buildEventsCell(morningEvents),
          _buildEventsCell(afternoonEvents),
          _buildEventsCell(eveningEvents),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title) {
    return Container(
      height: _sessionCellHeight,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      alignment: Alignment.center,
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
    );
  }

  Widget _buildDateHeaderCell(String dayTitle, DateTime date) {
    return Container(
      height: _headerHeight,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(dayTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
  
  Widget _buildEventsCell(List<Map<String, dynamic>> events) {
    return Container(
      height: _sessionCellHeight,
      width: _dayColumnWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: events.isEmpty
          ? null
          : ListView.builder(
              itemCount: events.length,
              padding: const EdgeInsets.all(8.0),
              itemBuilder: (context, index) => _buildEventItem(events[index]),
            ),
    );
  }

  /// Lấy màu sắc đại diện cho môn học.
  Color _getColorForSubject(String? subject) {
    if (subject == null) return Colors.blue.shade700;
    final String s = subject.toLowerCase();
    if (s.contains('toán')) return const Color(0xFFEF5350); // Red
    if (s.contains('văn')) return const Color(0xFFFFA726); // Orange
    if (s.contains('anh') || s.contains('english')) return const Color(0xFF42A5F5); // Blue
    if (s.contains('lý')) return const Color(0xFFAB47BC); // Purple
    if (s.contains('hóa')) return const Color(0xFF66BB6A); // Green
    if (s.contains('sinh')) return const Color(0xFF26A69A); // Teal
    if (s.contains('sử') || s.contains('địa')) return const Color(0xFF8D6E63); // Brown
    if (s.contains('gdcd')) return const Color(0xFF78909C); // Blue Grey
    return const Color(0xFF5C6BC0); // Indigo
  }

  String _formatTime(String? timeString) {
    if (timeString == null || timeString.length < 5) return '';
    return timeString.substring(0, 5);
  }

  /// Widget hiển thị một sự kiện lịch học.
  Widget _buildEventItem(Map<String, dynamic> event) {
    final color = _getColorForSubject(event['subject']);
    final startTime = _formatTime(event['startTime']);
    final endTime = _formatTime(event['endTime']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Show details dialog if needed
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event['subject'] ?? 'Môn học',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color.withOpacity(0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event['className'] ?? 'Lớp học',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '$startTime - $endTime',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event['room'] ?? 'Chưa cập nhật',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
