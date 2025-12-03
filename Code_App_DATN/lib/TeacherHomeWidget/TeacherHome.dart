import 'dart:async';
import 'package:app_quan_ly_tuyen_sinh/services/teacher/teacher_service.dart';
import 'package:flutter/material.dart';
import '../screens/teacher/NotificationScreen.dart';
import '../models/user.dart';

class TeacherHome extends StatefulWidget {
  final User user;
  const TeacherHome({super.key, required this.user});

  @override
  State<TeacherHome> createState() => TeacherHomeState();
}

class TeacherHomeState extends State<TeacherHome> {
  final TeacherService _teacherService = TeacherService();
  bool _isLoading = true;
  
  int _totalClasses = 0;
  int _totalStudents = 0;
  List<Map<String, dynamic>> _todayClasses = [];
  
  // Quản lý trạng thái và danh sách thông báo.

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  final List<Map<String, String>> _quotes = [
    {
      'content': 'Người thầy trung bình chỉ biết nói, người thầy giỏi biết giải thích, người thầy xuất chúng biết minh họa, người thầy vĩ đại biết cách truyền cảm hứng.',
      'author': 'William Arthur Ward'
    },
    {
      'content': 'Giáo dục không phải là việc đổ đầy một cái bình, mà là thắp sáng một ngọn lửa.',
      'author': 'William Butler Yeats'
    },
    {
      'content': 'Nghệ thuật dạy học chính là nghệ thuật giúp ai đó khám phá.',
      'author': 'Mark Van Doren'
    },
    {
      'content': 'Một người thầy tốt giống như ngọn nến - đốt cháy chính mình để soi sáng đường cho những người khác.',
      'author': 'Mustafa Kemal Atatürk'
    },
    {
      'content': 'Dạy học là nghề cao quý nhất trong các nghề cao quý.',
      'author': 'Khuyết danh'
    },
    {
      'content': 'Để là người thầy giỏi, bạn phải yêu những gì bạn dạy và yêu những người bạn dạy.',
      'author': 'Khuyết danh'
    },
    {
      'content': 'Sự gương mẫu của người thầy giáo là tia sáng mặt trời thuận lợi nhất đối với sự phát triển tâm hồn non trẻ mà không có gì thay thế được.',
      'author': 'Ushinsky'
    },
    {
      'content': 'Nhân cách của người thầy là sức mạnh có ảnh hưởng to lớn đối với học sinh, sức mạnh đó không thể thay thế bằng bất kỳ cuốn sách giáo khoa nào.',
      'author': 'Ushinsky'
    },
    {
      'content': 'Dưới ánh mặt trời không có nghề nào cao quý hơn nghề dạy học.',
      'author': 'Comenius'
    },
  ];

  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoScroll();
    _startNotificationTimer();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notificationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Timer? _notificationTimer;

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < _quotes.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final notifications = await _teacherService.getNotifications();
      
      // Lọc chỉ thông báo SYSTEM
      final systemNotifs = notifications.where((n) {
        final notifType = (n['notificationType'] ?? n['notification_type'] ?? '').toString().toUpperCase();
        return notifType == 'SYSTEM';
      }).toList();
      
      if (mounted) {
        setState(() {
          _notifications = systemNotifs;
          _unreadCount = systemNotifs.where((n) {
            final rawIsRead = n['isRead'] ?? n['is_read'];
            final isRead = rawIsRead == 1 || rawIsRead == true || rawIsRead == '1';
            return !isRead;
          }).length;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing notifications: $e');
    }
  }

  // Phương thức reload công khai để hỗ trợ tính năng làm mới bằng thao tác chạm hai lần.

  Future<void> reload() async {
    await _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      // Tải danh sách các lớp học để thực hiện thống kê.

      final classes = await _teacherService.getTeacherClasses();
      
      // Tính toán các chỉ số thống kê tổng quan.

      _totalClasses = classes.length;
      
      // Tính tổng số lượng học viên bằng cách tải danh sách chi tiết cho từng lớp.

      int totalStudents = 0;
      for (final cls in classes) {
        try {
          final classId = cls['classId'] ?? cls['id'];
          if (classId != null) {
            final students = await _teacherService.getClassStudents(classId);
            totalStudents += students.length;
            // Cập nhật số lượng học viên cho lớp học để hiển thị trên giao diện.

            cls['studentCount'] = students.length; 
          }
        } catch (e) {
          debugPrint('Error loading student count for class ${cls['id']}: $e');
          // Sử dụng số lượng hiện có làm phương án dự phòng nếu tải thất bại.

          final studentCount = cls['studentCount'] ?? cls['currentStudents'] ?? 0;
          totalStudents += (studentCount is int) ? studentCount : int.tryParse(studentCount.toString()) ?? 0;
        }
      }
      _totalStudents = totalStudents;

      // Tải lịch giảng dạy cho các lớp trong ngày hôm nay.

      final schedule = await _teacherService.getTeacherSchedule();
      
      // Xác định khóa ngày hiện tại để lọc lịch dạy.

      final now = DateTime.now();
      String dayKey = '';
      switch (now.weekday) {
        case 1: dayKey = 'Thứ 2'; break;
        case 2: dayKey = 'Thứ 3'; break;
        case 3: dayKey = 'Thứ 4'; break;
        case 4: dayKey = 'Thứ 5'; break;
        case 5: dayKey = 'Thứ 6'; break;
        case 6: dayKey = 'Thứ 7'; break;
        case 7: dayKey = 'Chủ Nhật'; break;
      }
      
      final allTodayClasses = schedule[dayKey] ?? [];
      final todayDate = DateTime(now.year, now.month, now.day);
      
      _todayClasses = allTodayClasses.where((cls) {
        final classEnd = cls['classEnd'] as DateTime?;
        // Giữ lại nếu chưa có ngày kết thúc HOẶC ngày kết thúc >= hôm nay
        return classEnd == null || !classEnd.isBefore(todayDate);
      }).toList();

      // Tải danh sách thông báo mới nhất.

      try {
        final allNotifications = await _teacherService.getNotifications();
        
        // Lọc chỉ thông báo SYSTEM
        final systemNotifs = allNotifications.where((n) {
          final notifType = (n['notificationType'] ?? n['notification_type'] ?? '').toString().toUpperCase();
          return notifType == 'SYSTEM';
        }).toList();
        
        _notifications = systemNotifs;
        // Đếm số lượng thông báo chưa đọc.

        _unreadCount = systemNotifs.where((n) {
          final rawIsRead = n['isRead'] ?? n['is_read'];
          final isRead = rawIsRead == 1 || rawIsRead == true || rawIsRead == '1';
          return !isRead;
        }).length;
      } catch (e) {
        // Error loading notifications
        // Đảm bảo lỗi tải thông báo không ảnh hưởng đến toàn bộ bảng điều khiển.

      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải dữ liệu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Trang chủ'),
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
                      builder: (context) => AppNotificationScreen(notifications: _notifications),
                    ),
                  ).then((_) => _loadDashboardData()); // Tải lại dữ liệu bảng điều khiển khi quay lại từ màn hình thông báo.

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
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hiển thị thẻ chào mừng giáo viên.

                    _buildWelcomeCard(),
                    const SizedBox(height: 16),

                    // Hiển thị các thẻ thống kê số liệu.

                    _buildStatisticsCards(),
                    const SizedBox(height: 24),

                    // Hiển thị danh sách các lớp học trong ngày hôm nay.

                    _buildTodayClasses(),
                    const SizedBox(height: 24),

                    // Hiển thị góc cảm hứng (Thay thế cho mục Thao tác nhanh).

                    _buildInspirationSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 35, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Xin chào,',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.fullName ?? 'Giáo viên',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.class_,
            title: 'Lớp học',
            value: _totalClasses.toString(),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            title: 'Học viên',
            value: _totalStudents.toString(),
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayClasses() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lịch dạy hôm nay',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_todayClasses.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  'Không có lớp học nào hôm nay',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          ..._todayClasses.map((cls) => _buildClassCard(cls)),
      ],
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData) {
    final className = classData['name'] ?? classData['className'] ?? 'Lớp học';
    
    dynamic subjectRaw = classData['subject'];
    String subject = '';
    if (subjectRaw is Map) {
      subject = subjectRaw['name'] ?? '';
    } else if (subjectRaw is String) {
      subject = subjectRaw;
    } else {
      subject = classData['subjectName'] ?? '';
    }

    String formatTime(dynamic t) {
      String s = t.toString();
      if (s.length > 5) return s.substring(0, 5);
      return s;
    }

    final startTime = formatTime(classData['startTime'] ?? '');
    final endTime = formatTime(classData['endTime'] ?? '');
    final timeDisplay = (startTime.isNotEmpty && endTime.isNotEmpty) 
        ? '$startTime - $endTime' 
        : 'Chưa có giờ';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: const Icon(Icons.access_time, color: Colors.blue),
        ),
        title: Text(className, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$subject • $timeDisplay'),
      ),
    );
  }

  Widget _buildInspirationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Góc cảm hứng',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220, // Tăng chiều cao widget để tránh lỗi tràn giao diện.

          child: PageView.builder(
            controller: _pageController,
            itemCount: _quotes.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              final quote = _quotes[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4), // Thêm khoảng cách đệm giữa các thẻ.

                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade300, Colors.orange.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.white, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        '"${quote['content']}"',
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '- ${quote['author']}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Hiển thị chỉ báo trang (dấu chấm) cho PageView.

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_quotes.length, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index ? Colors.orange : Colors.grey.shade300,
              ),
            );
          }),
        ),
      ],
    );
  }
}
