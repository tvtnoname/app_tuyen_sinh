import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/parent/parent_service.dart';
import '../screens/parent/ParentNotificationScreen.dart';

/// Màn hình chính dành cho Phụ huynh.
/// Hiển thị thông tin tổng quan, danh sách con em, góc cảm hứng và thông tin liên hệ của trung tâm.
class ParentHomeTab extends StatefulWidget {
  final User user;
  const ParentHomeTab({super.key, required this.user});

  @override
  State<ParentHomeTab> createState() => ParentHomeTabState();
}

class ParentHomeTabState extends State<ParentHomeTab> {
  final ParentService _parentService = ParentService();
  
  bool _isLoading = true;
  Map<String, dynamic>? _parentProfile;
  List<Map<String, dynamic>> _children = [];
  Timer? _notificationTimer;
  int _unreadNotifications = 0;

  // Dữ liệu cho Góc cảm hứng
  final List<Map<String, String>> _quotes = [
    {
      'content': 'Cha mẹ là người thầy đầu tiên và quan trọng nhất của con cái.',
      'author': 'Khuyết danh'
    },
    {
      'content': 'Hãy để con cái bạn nhìn thấy bạn đọc sách, đó là cách tốt nhất để dạy chúng yêu sách.',
      'author': 'Khuyết danh'
    },
    {
      'content': 'Giáo dục gia đình là nền tảng của mọi giáo dục.',
      'author': 'Viên Hiểu'
    },
    {
      'content': 'Cách tốt nhất để dạy con là làm gương cho con.',
      'author': 'Khuyết danh'
    },
    {
      'content': 'Đừng chỉ dạy con làm giàu, hãy dạy con hạnh phúc.',
      'author': 'Khuyết danh'
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
    _loadData();
    _startNotificationTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Bắt đầu tự động cuộn cho Góc cảm hứng.
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

  /// Tải dữ liệu hồ sơ phụ huynh và danh sách con em từ API.
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _parentService.getParentProfile();
      final children = await _parentService.getChildren();
      
      if (mounted) {
        setState(() {
          _parentProfile = profile;
          _children = children;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi khi tải dữ liệu phụ huynh: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Tải lại dữ liệu (dùng cho tính năng kéo để làm mới).
  Future<void> reload() async {
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang tải lại trang chủ...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Trang chủ'),
        automaticallyImplyLeading: false, // Ẩn nút back vì đây là tab chính
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  int studentId = widget.user.id ?? 0;
                  if (_children.isNotEmpty) {
                     studentId = _children.first['studentId'] ?? _children.first['id'] ?? studentId;
                  }
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParentNotificationScreen(studentId: studentId),
                    ),
                  );
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 24),
                    _buildInspirationSection(),
                    const SizedBox(height: 24),
                    _buildChildrenSection(),
                    const SizedBox(height: 24),
                    _buildContactSection(),
                  ],
                ),
              ),
            ),
    );
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

  /// Xây dựng thẻ chào mừng phụ huynh.
  Widget _buildWelcomeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blueGrey.shade400, Colors.blueGrey.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 35, color: Colors.blueGrey),
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
                    _parentProfile?['user']?['fullName'] ?? widget.user.fullName ?? 'Phụ huynh',
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

  /// Xây dựng phần Góc cảm hứng với các câu nói hay.
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
          height: 220,
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
                margin: const EdgeInsets.symmetric(horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade300, Colors.teal.shade500],
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_quotes.length, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index ? Colors.teal : Colors.grey.shade300,
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Xây dựng danh sách con em.
  Widget _buildChildrenSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Danh sách con em',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_children.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  'Chưa có thông tin học sinh liên kết',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          ..._children.map((child) => _buildChildCard(child)),
      ],
    );
  }

  /// Xây dựng phần thông tin liên hệ của trung tâm.
  Widget _buildContactSection() {
    if (_children.isEmpty) return const SizedBox.shrink();
    
    // Tìm thông tin chi nhánh từ dữ liệu của con
    Map<String, dynamic>? branch;
    for (var child in _children) {
      // Kiểm tra studentClasses -> clazz -> branch
      if (child['studentClasses'] != null && child['studentClasses'] is List) {
        final classes = child['studentClasses'] as List;
        for (var cls in classes) {
          if (cls is Map && cls['clazz'] != null && cls['clazz'] is Map) {
            final clazz = cls['clazz'];
            if (clazz['branch'] != null && clazz['branch'] is Map) {
              branch = clazz['branch'];
              break;
            }
          }
        }
      }
      if (branch != null) break;

      // Kiểm tra dự phòng (giữ logic cũ để an toàn)
      if (child['branch'] != null) {
        branch = child['branch'];
        break;
      }
    }
    
    final centerName = branch?['name'] ?? 'Trung tâm Quản lý Đào tạo';
    final centerPhone = branch?['phone1'] ?? branch?['phone2'] ?? '0987.654.321';
    final centerEmail = branch?['email'] ?? 'contact@education.com';
    final centerAddress = branch?['address'] ?? 'Hà Nội, Việt Nam';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Thông tin liên hệ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildContactRow(Icons.business, 'Trung tâm', centerName),
                const Divider(),
                _buildContactRow(Icons.phone, 'Hotline', centerPhone, isPhone: true),
                const Divider(),
                _buildContactRow(Icons.email, 'Email', centerEmail),
                const Divider(),
                _buildContactRow(Icons.location_on, 'Địa chỉ', centerAddress),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Widget hiển thị một dòng thông tin liên hệ.
  Widget _buildContactRow(IconData icon, String label, String value, {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isPhone ? Colors.blue : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (isPhone)
            IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () {
                // Thực hiện chức năng gọi điện
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gọi đến $value...')),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Widget hiển thị thẻ thông tin của một học sinh (con).
  Widget _buildChildCard(Map<String, dynamic> child) {
    final name = child['user']?['fullName'] ?? child['fullName'] ?? child['name'] ?? 'Học sinh';
    final studentCode = child['studentCode'] ?? child['code'] ?? 'N/A';
    
    // Sử dụng khối lớp thay vì lớp học cụ thể nếu có
    final className = child['className'] ?? child['class'] ?? (child['gradeLevel'] != null ? 'Khối ${child['gradeLevel']}' : 'N/A');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: const Icon(Icons.face, color: Colors.blue),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Mã HS: $studentCode • $className'),
      ),
    );
  }
}
