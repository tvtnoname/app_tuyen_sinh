import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/teacher/teacher_service.dart';
import '../screens/teacher/NotificationScreen.dart';

class TeacherSchedule extends StatefulWidget {
  const TeacherSchedule({super.key});

  @override
  State<TeacherSchedule> createState() => TeacherScheduleState();
}

class TeacherScheduleState extends State<TeacherSchedule> {
  final TeacherService _teacherService = TeacherService();
  late DateTime _selectedDate;
  Map<String, List<Map<String, dynamic>>> _scheduleByDay = {};
  bool _isLoading = true;

  // Định nghĩa các hằng số kích thước cho giao diện lịch.
  static const double _headerHeight = 60.0;
  static const double _sessionCellHeight = 220.0;
  static const double _sessionHeaderWidth = 60.0;
  static const double _dayColumnWidth = 220.0;

  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadSchedule();
    _startNotificationTimer();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final notifications = await _teacherService.getNotifications();
      if (mounted) {
        setState(() {
          _unreadCount = notifications.where((n) {
            final isRead = n['isRead'];
            return isRead == 0 || isRead == null;
          }).length;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing notifications: $e');
    }
  }

  int _unreadCount = 0;

  Future<void> _loadSchedule() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final result = await _teacherService.getTeacherSchedule();
      
      // Tải danh sách thông báo để cập nhật số lượng chưa đọc trên biểu tượng.

      try {
        final notifications = await _teacherService.getNotifications();
        _unreadCount = notifications.where((n) {
          final isRead = n['isRead'];
          return isRead == 0 || isRead == null;
        }).length;
      } catch (e) {
        debugPrint('Error loading notifications: $e');
      }

      if (mounted) {
        setState(() {
          _scheduleByDay = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('TeacherSchedule._loadSchedule error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Phương thức reload công khai để hỗ trợ tính năng làm mới bằng thao tác chạm hai lần.

  Future<void> reload() async {
    await _loadSchedule();
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

  // Kiểm tra xem một ngày cụ thể có nằm trong khoảng thời gian hiệu lực của lớp học hay không.
  bool _isDateWithinClassRange(DateTime dayDate, dynamic classStart, dynamic classEnd) {
    // Nếu không có thông tin thời gian bắt đầu/kết thúc, mặc định lớp học đang hoạt động.

    if (classStart == null && classEnd == null) return true;
    
    try {
      // Chuẩn hóa ngày cần kiểm tra về thời điểm đầu ngày (00:00:00).

      final DateTime dateToCheck = DateTime(dayDate.year, dayDate.month, dayDate.day);
      
      DateTime? start;
      if (classStart != null) {
        final s = classStart is DateTime ? classStart : DateTime.tryParse(classStart.toString());
        if (s != null) start = DateTime(s.year, s.month, s.day);
      }
      
      DateTime? end;
      if (classEnd != null) {
        final e = classEnd is DateTime ? classEnd : DateTime.tryParse(classEnd.toString());
        if (e != null) end = DateTime(e.year, e.month, e.day);
      }
      
      // Kiểm tra ngày bắt đầu (bao gồm cả ngày bắt đầu).

      if (start != null && dateToCheck.isBefore(start)) {
        return false;
      }
      
      // Kiểm tra ngày kết thúc (bao gồm cả ngày kết thúc).
      // Theo yêu cầu: vẫn chấp nhận ngày kết thúc.
      // Chỉ loại bỏ khi ngày kiểm tra thực sự nằm sau ngày kết thúc.

      if (end != null && dateToCheck.isAfter(end)) {
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('TeacherSchedule._isDateWithinClassRange error: $e');
      return true;      // Nếu xảy ra lỗi trong quá trình kiểm tra, mặc định hiển thị lớp học để tránh mất dữ liệu.

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Lịch dạy', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppNotificationScreen(),
                    ),
                  ).then((_) => _loadSchedule());
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
                  : GestureDetector(
                      onDoubleTap: () {
                        // Nhấn đúp để tải lại dữ liệu lịch giảng dạy.

                        _loadSchedule();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đang tải lại lịch dạy...'),
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
    // Các khóa ngày khớp với định dạng trả về từ TeacherService (ví dụ: 'Thứ 2', 'Thứ 3'...).

    final daysOfWeek = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'];
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
                final isSelected = date.year == _selectedDate.year && 
                                   date.month == _selectedDate.month && 
                                   date.day == _selectedDate.day;
                
                // Lấy danh sách các sự kiện tương ứng với ngày hiện tại.

                final events = (_scheduleByDay[dayName] ?? []).toList();
                
                return _buildDayColumn(dayName, date, events, isSelected: isSelected);
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

  Widget _buildDayColumn(String dayTitle, DateTime date, List<Map<String, dynamic>> events, {bool isSelected = false}) {
    // Lọc sự kiện để chỉ hiển thị những lớp học đang trong thời gian hoạt động.

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
        color: isSelected ? Colors.blue.withOpacity(0.05) : null, // Highlight background
      ),
      child: Column(
        children: [
          _buildDateHeaderCell(dayTitle, date, isSelected: isSelected),
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

  Widget _buildDateHeaderCell(String dayTitle, DateTime date, {bool isSelected = false}) {
    return Container(
      height: _headerHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade100 : null,
        border: isSelected ? Border(bottom: BorderSide(color: Colors.blue, width: 2)) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dayTitle, 
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.blue.shade800 : Colors.black87,
            )
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('dd/MM').format(date), 
            style: TextStyle(
              fontSize: 13, 
              color: isSelected ? Colors.blue.shade800 : Colors.grey
            )
          ),
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

  Color _getColorForSubject(String? subject) {
    if (subject == null) return Colors.blue.shade700;
    final String s = subject.toLowerCase();
    if (s.contains('toán')) return Colors.red.shade600;
    if (s.contains('văn')) return Colors.orange.shade800;
    if (s.contains('anh') || s.contains('english')) return Colors.blue.shade700;
    if (s.contains('lý')) return Colors.purple.shade600;
    if (s.contains('hóa')) return Colors.green.shade700;
    if (s.contains('sinh')) return Colors.teal.shade700;
    return Colors.indigo.shade600;
  }

  String _formatTime(String? timeString) {
    if (timeString == null || timeString.length < 5) return '';
    return timeString.substring(0, 5);
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final color = _getColorForSubject(event['subject']);
    final startTime = _formatTime(event['startTime']);
    final endTime = _formatTime(event['endTime']);

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event['className'] ?? 'Lớp học',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              event['subject'] ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, '$startTime - $endTime'),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.location_on_outlined, event['location'] ?? 'N/A'),
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
