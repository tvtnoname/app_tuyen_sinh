import 'dart:async';
import 'package:flutter/material.dart';
import '../services/parent/parent_service.dart';
import '../screens/parent/ParentNotificationScreen.dart';

/// Màn hình quản lý thanh toán học phí dành cho Phụ huynh.
/// Hiển thị tổng quan công nợ, lịch sử thanh toán và trạng thái các khoản phí.
class ParentPaymentTab extends StatefulWidget {
  const ParentPaymentTab({super.key});

  @override
  State<ParentPaymentTab> createState() => ParentPaymentTabState();
}

class ParentPaymentTabState extends State<ParentPaymentTab> {
  final ParentService _parentService = ParentService();
  Timer? _notificationTimer;
  Map<String, dynamic>? _selectedChild;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _children = [];

  @override
  void initState() {
    super.initState();
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

  /// Tải danh sách con em để xác định học sinh đang được chọn.
  Future<void> _loadChildren() async {
    try {
      final children = await _parentService.getChildren();
      if (mounted) {
        setState(() {
          _children = children;
          if (_children.isNotEmpty) {
            _selectedChild = _children.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Lỗi khi tải danh sách con: $e');
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  /// Tải lại dữ liệu (dùng cho tính năng kéo để làm mới hoặc cập nhật thủ công).
  Future<void> reload() async {
    // Mô phỏng việc tải lại dữ liệu
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang tải lại thông tin thanh toán...'),
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
        title: const Text('Thanh toán học phí'),
        automaticallyImplyLeading: false,
        elevation: 0,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 24),
            const Text(
              'Lịch sử thanh toán',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildPaymentItem(
              title: 'Học phí Tháng 11/2025',
              amount: '2.500.000 đ',
              date: '15/11/2025',
              status: 'Đã thanh toán',
              isPaid: true,
            ),
            _buildPaymentItem(
              title: 'Phí bán trú Tháng 11/2025',
              amount: '1.200.000 đ',
              date: '15/11/2025',
              status: 'Đã thanh toán',
              isPaid: true,
            ),
            _buildPaymentItem(
              title: 'Học phí Tháng 10/2025',
              amount: '2.500.000 đ',
              date: '10/10/2025',
              status: 'Đã thanh toán',
              isPaid: true,
            ),
             _buildPaymentItem(
              title: 'Phí đồng phục',
              amount: '500.000 đ',
              date: '05/09/2025',
              status: 'Đã thanh toán',
              isPaid: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị thẻ tổng quan công nợ.
  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Học phí chưa thanh toán',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '0 đ',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('Thanh toán ngay'),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị một mục lịch sử thanh toán.
  Widget _buildPaymentItem({
    required String title,
    required String amount,
    required String date,
    required String status,
    required bool isPaid,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
          child: Icon(
            isPaid ? Icons.check_circle : Icons.pending,
            color: isPaid ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(date),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              status,
              style: TextStyle(
                color: isPaid ? Colors.green : Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
