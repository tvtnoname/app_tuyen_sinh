import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../services/student/schedule_service.dart';
import '../services/student/student_service.dart';
import '../screens/student/StudentNotificationScreen.dart';

class Schedule extends StatefulWidget {
  final User user;
  const Schedule({Key? key, required this.user}) : super(key: key);

  @override
  State<Schedule> createState() => ScheduleState();
}

class ScheduleState extends State<Schedule> {
  final ScheduleService _scheduleService = ScheduleService();
  final StudentService _studentService = StudentService();
  late DateTime _selectedDate;
  Map<String, List<Map<String, dynamic>>> _scheduleByDay = {};
  bool _isLoading = true;
  int _unreadNotifications = 0;
  Timer? _notificationTimer;

  // Hằng số kích thước giao diện

  static const double _headerHeight = 60.0;
  static const double _sessionCellHeight = 220.0;
  static const double _sessionHeaderWidth = 60.0;
  static const double _dayColumnWidth = 220.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadSchedule();
    _loadUnreadNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadUnreadNotifications();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadNotifications() async {
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
          _unreadNotifications = unreadCount;
        });
      }
    } catch (e) {
      // Error loading unread notifications
    }
  }

  Future<void> reload() async {
    await _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final result = await _scheduleService.getScheduleForUser(widget.user);
      if (mounted) setState(() => _scheduleByDay = result);
    } catch (e) {
      debugPrint('Schedule._loadSchedule service error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToPreviousWeek() => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 7)));
  void _goToNextWeek() => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 7)));
  void _goToCurrentWeek() => setState(() => _selectedDate = DateTime.now());

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

  bool _isDateWithinClassRange(DateTime dayDate, dynamic classStart, dynamic classEnd) {
    try {
      DateTime? normalize(dynamic v) {
        if (v == null) return null;
        if (v is DateTime) return DateTime(v.toLocal().year, v.toLocal().month, v.toLocal().day);
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return DateTime(parsed.toLocal().year, parsed.toLocal().month, parsed.toLocal().day);
        }
        return null;
      }
      final start = normalize(classStart);
      final end = normalize(classEnd);
      if (start == null && end == null) return true;
      final dayOnly = DateTime(dayDate.year, dayDate.month, dayDate.day);
      if (start != null && dayOnly.isBefore(start)) return false;
      if (end != null && dayOnly.isAfter(end)) return false;
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.only(top: 40.0, left: 16.0, right: 16.0),
        child: Column(
          children: [
            _buildHeader(context, widget.user),
            const SizedBox(height: 12),
            _buildToolbar(),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GestureDetector(
                      onDoubleTap: () {
                        // Nhấn đúp để làm mới lịch học

                        _loadSchedule();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đang tải lại lịch học...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
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

  Widget _buildScheduleGrid() {
    final daysOfWeek = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
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
                final date = startOfWeek.add(Duration(days: entry.key));
                final events = (_scheduleByDay[dayName] ?? []).where((event) {
                  return _isDateWithinClassRange(date, event['classStart'], event['classEnd']);
                }).toList();
                return _buildDayColumn(dayName, date, events);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

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

  Widget _buildDayColumn(String dayTitle, DateTime date, List<Map<String, dynamic>> events) {
    final morningEvents = events.where((e) {
      final time = e['time'] as String?;
      if (time == null) return false;
      return time.compareTo('13:30') < 0;
    }).toList();

    final afternoonEvents = events.where((e) {
      final time = e['time'] as String?;
      if (time == null) return false;
      return time.compareTo('13:30') >= 0 && time.compareTo('17:30') < 0;
    }).toList();

    final eveningEvents = events.where((e) {
      final time = e['time'] as String?;
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

  Widget _buildHeader(BuildContext context, User user) {
    final displayName = user.fullName ?? user.userName ?? 'bạn';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('Lịch học của', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Colors.grey[700])),
                const SizedBox(height: 4),
                Text(displayName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentNotificationScreen(studentId: widget.user.id ?? 0),
                    ),
                  ).then((_) => _loadUnreadNotifications()); // Tải lại thông báo khi quay về màn hình này


                },
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

  Color _getColorFromString(String? colorString) {
    switch (colorString) {
      case 'blue': return Colors.blue.shade700;
      case 'green': return Colors.green.shade700;
      case 'red': return Colors.red.shade600;
      case 'orange': return Colors.orange.shade800;
      default: return Colors.grey.shade700;
    }
  }

  String _formatTime(String? timeString) {
    if (timeString == null || timeString.length < 5) return '';
    return timeString.substring(0, 5);
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final color = _getColorFromString(event['color']);
    final startTime = _formatTime(event['time']);
    final endTime = _formatTime(event['endTime']);
    final teacherName = event['teacher'];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event['subject'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, '$startTime - $endTime'),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.location_on_outlined, event['location'] ?? 'N/A'),
            if (teacherName != null) ...[
              const SizedBox(height: 4),
              _buildInfoRow(Icons.person_outline, 'GV: $teacherName'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade700),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade800))),
      ],
    );
  }
}