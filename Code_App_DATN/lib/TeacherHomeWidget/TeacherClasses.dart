import 'dart:async';
import 'package:app_quan_ly_tuyen_sinh/screens/teacher/NotificationScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/teacher/ClassDetailScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/services/teacher/teacher_service.dart';
import 'package:flutter/material.dart';

class TeacherClasses extends StatefulWidget {
  const TeacherClasses({super.key});

  @override
  State<TeacherClasses> createState() => TeacherClassesState();
}

class TeacherClassesState extends State<TeacherClasses> {
  final TeacherService _teacherService = TeacherService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _classes = [];

  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _loadClasses();
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

  // Phương thức reload công khai để hỗ trợ tính năng làm mới bằng thao tác chạm hai lần.

  Future<void> reload() async {
    await _loadClasses();
  }

  int _unreadCount = 0;
  String _selectedFilter = 'active'; // 'active' or 'completed'
  int? _selectedSemesterId;

  List<Map<String, dynamic>> _getAvailableSemesters() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final completedClasses = _classes.where((cls) {
      DateTime? endDate;
      try {
        final endStr = cls['endDate'] ?? cls['end_date'] ?? cls['end'];
        if (endStr != null) {
          endDate = DateTime.parse(endStr.toString());
        }
      } catch (_) {}
      return endDate != null && endDate.isBefore(today);
    }).toList();

    final Map<int, Map<String, dynamic>> semesters = {};
    for (var cls in completedClasses) {
      if (cls['semester'] is Map) {
        final sem = cls['semester'];
        final id = sem['semesterId'] ?? sem['id'];
        if (id != null) {
          semesters[id] = {
            'id': id,
            'name': sem['name'] ?? 'Học kỳ $id',
          };
        }
      }
    }
    return semesters.values.toList();
  }

  List<Map<String, dynamic>> _getFilteredClasses() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _classes.where((cls) {
      // Lấy ngày kết thúc
      DateTime? endDate;
      try {
        final endStr = cls['endDate'] ?? cls['end_date'] ?? cls['end'];
        if (endStr != null) {
          endDate = DateTime.parse(endStr.toString());
        }
      } catch (_) {}

      if (_selectedFilter == 'active') {
        // Đang dạy: Chưa có ngày kết thúc HOẶC ngày kết thúc >= hôm nay
        return endDate == null || !endDate.isBefore(today);
      } else {
        // Đã kết thúc: Ngày kết thúc < hôm nay
        final isCompleted = endDate != null && endDate.isBefore(today);
        if (!isCompleted) return false;

        if (_selectedSemesterId != null) {
           final semId = cls['semester'] is Map ? (cls['semester']['semesterId'] ?? cls['semester']['id']) : null;
           return semId == _selectedSemesterId;
        }
        return true;
      }
    }).toList();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Tải thông tin cơ bản của các lớp học được phân công.

      final classes = await _teacherService.getTeacherClasses();
      
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
          _classes = classes;
          _isLoading = false;
        });
      }

      // 2. Tải số lượng học viên thực tế cho từng lớp học dưới nền.

      for (var i = 0; i < classes.length; i++) {
        try {
          final classId = classes[i]['classId'] ?? classes[i]['id'];
          if (classId != null) {
            final students = await _teacherService.getClassStudents(classId);
            
            if (mounted) {
              setState(() {
                _classes[i]['studentCount'] = students.length;
              });
            }
          }
        } catch (e) {
          debugPrint('Error loading student count for class ${classes[i]['id']}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải danh sách lớp: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Lớp học của tôi'),
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
                  ).then((_) => _loadClasses());
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Bộ lọc trạng thái
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildFilterChip('Đang dạy', 'active'),
                          const SizedBox(width: 12),
                          _buildFilterChip('Đã kết thúc', 'completed'),
                        ],
                      ),
                      if (_selectedFilter == 'completed' && _getAvailableSemesters().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              hint: const Text('Tất cả học kỳ'),
                              value: _selectedSemesterId,
                              items: [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Tất cả học kỳ'),
                                ),
                                ..._getAvailableSemesters().map((sem) {
                                  return DropdownMenuItem<int>(
                                    value: sem['id'],
                                    child: Text(sem['name']),
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
                    ],
                  ),
                ),
                
                // Danh sách lớp học
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadClasses,
                    child: _getFilteredClasses().isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedFilter == 'active' ? Icons.class_ : Icons.history,
                                  size: 80, 
                                  color: Colors.grey[400]
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedFilter == 'active' 
                                      ? 'Không có lớp đang dạy' 
                                      : 'Không có lớp đã kết thúc',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _getFilteredClasses().length + 1,
                            itemBuilder: (context, index) {
                              final filteredList = _getFilteredClasses();
                              
                              if (index == filteredList.length) {
                                // Tính tổng số lượng học viên từ danh sách ĐÃ LỌC.
                                int totalStudents = 0;
                                for (var cls in filteredList) {
                                  final count = cls['studentCount'] ?? cls['currentStudents'] ?? 0;
                                  totalStudents += (count is int) ? count : int.tryParse(count.toString()) ?? 0;
                                }
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                                  child: Center(
                                    child: Text(
                                      'Tổng số học viên (${_selectedFilter == 'active' ? 'Đang dạy' : 'Đã kết thúc'}): $totalStudents',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return _buildClassCard(filteredList[index]);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected 
                ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData) {
    final className = classData['name'] ?? classData['className'] ?? 'Lớp học';
    final classId = classData['classId'] ?? classData['id'];
    
    // Trích xuất thông tin môn học và khối lớp từ dữ liệu.

    String subjectName = '';
    String gradeName = '';
    String semesterName = '';
    
    try {
      if (classData['subject'] is Map) {
        subjectName = classData['subject']['name'] ?? '';
      }
      if (classData['grade'] is Map) {
        gradeName = classData['grade']['name'] ?? '';
      }
      if (classData['semester'] is Map) {
        semesterName = classData['semester']['name'] ?? '';
      }
    } catch (_) {}

    final description = [subjectName, gradeName, semesterName].where((s) => s.isNotEmpty).join(' · ');
    
    // Lấy số lượng học viên hiện tại.

    final studentCount = classData['studentCount'] ?? classData['currentStudents'] ?? 0;
    
    // Tạo chuỗi tóm tắt lịch học từ danh sách thời khóa biểu.

    String scheduleText = 'Chưa có lịch';
    try {
      if (classData['classSchedules'] is List && (classData['classSchedules'] as List).isNotEmpty) {
        final schedules = classData['classSchedules'] as List;
        // Ánh xạ khoảng thời gian "bắt đầu - kết thúc" sang danh sách các ngày trong tuần.

        final Map<String, List<String>> timeToDays = {};

        for (final schedule in schedules) {
          if (schedule is Map) {
            final dow = schedule['dayOfWeek'] ?? schedule['day_of_week'];
            if (dow != null) {
              final dayName = _getDayName(dow is int ? dow : int.tryParse(dow.toString()) ?? 0);
              
              // Trích xuất thời gian bắt đầu và kết thúc của tiết học.

              String timeRange = '';
              if (schedule['lessonSlot'] is Map) {
                 final ls = schedule['lessonSlot'];
                 final start = ls['startTime'] ?? ls['start_time'];
                 final end = ls['endTime'] ?? ls['end_time'];
                 if (start != null && end != null) {
                   // Định dạng chuỗi thời gian (ví dụ: loại bỏ phần giây nếu có).

                   String formatTime(dynamic t) {
                     String s = t.toString();
                     if (s.length > 5) return s.substring(0, 5);
                     return s;
                   }
                   timeRange = '(${formatTime(start)} - ${formatTime(end)})';
                 }
              }
              
              // Nếu không có thông tin lessonSlot, thử lấy dữ liệu từ các trường trực tiếp (phương án dự phòng).

              if (timeRange.isEmpty) {
                 final start = schedule['startTime'] ?? schedule['start_time'];
                 final end = schedule['endTime'] ?? schedule['end_time'];
                 if (start != null && end != null) {
                    String formatTime(dynamic t) {
                     String s = t.toString();
                     if (s.length > 5) return s.substring(0, 5);
                     return s;
                   }
                   timeRange = '(${formatTime(start)} - ${formatTime(end)})';
                 }
              }

              timeToDays.putIfAbsent(timeRange, () => []).add(dayName);
            }
          }
        }
        
        if (timeToDays.isNotEmpty) {
          final parts = <String>[];
          timeToDays.forEach((time, days) {
             // Nối danh sách các ngày thành chuỗi, ví dụ: "Thứ 2, Thứ 4".
             // Sử dụng LinkedHashSet để đảm bảo thứ tự và loại bỏ các ngày trùng lặp.

             final uniqueDays = days.toSet().join(', ');
             if (time.isNotEmpty) {
               parts.add('$uniqueDays $time');
             } else {
               parts.add(uniqueDays);
             }
          });
          scheduleText = parts.join('\n');
        }
      }
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClassDetailScreen(classData: classData),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.class_, color: Colors.blue, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          className,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.people,
                      label: '$studentCount học viên',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoChip(
                icon: Icons.calendar_today,
                label: scheduleText,
                color: Colors.orange,
              ),
              const SizedBox(height: 8),
              _buildInfoChip(
                icon: Icons.date_range,
                label: _formatDateRange(classData),
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.notifications_active, size: 18),
                  label: const Text('Gửi thông báo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showSendNotificationDialog(context, classId, className),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  String _getDayName(int dayOfWeek) {
    const days = {
      1: 'Thứ Hai',
      2: 'Thứ Ba',
      3: 'Thứ Tư',
      4: 'Thứ Năm',
      5: 'Thứ Sáu',
      6: 'Thứ Bảy',
      7: 'Chủ Nhật',
    };
    return days[dayOfWeek] ?? 'N/A';
  }

  String _formatDateRange(Map<String, dynamic> classData) {
    try {
      final startStr = classData['startDate'] ?? classData['start_date'] ?? classData['start'];
      final endStr = classData['endDate'] ?? classData['end_date'] ?? classData['end'];
      
      if (startStr == null && endStr == null) return 'Chưa có thời gian';

      String formatDate(dynamic dateStr) {
        if (dateStr == null) return '?';
        try {
          final date = DateTime.parse(dateStr.toString());
          return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
        } catch (_) {
          return dateStr.toString();
        }
      }

      return '${formatDate(startStr)} - ${formatDate(endStr)}';
    } catch (_) {
      return 'Chưa có thời gian';
    }
  }
  Future<void> _showSendNotificationDialog(BuildContext context, int classId, String className) async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool isSending = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Gửi thông báo đến $className'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      if (titleController.text.isEmpty || messageController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập đầy đủ tiêu đề và nội dung')),
                        );
                        return;
                      }

                      setState(() => isSending = true);

                      final success = await _teacherService.sendClassNotification(
                        classId,
                        titleController.text,
                        messageController.text,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gửi thông báo thành công')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gửi thông báo thất bại')),
                          );
                        }
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
  }
}
