import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/student/student_service.dart';

class StudentNotificationScreen extends StatefulWidget {
  final int studentId;

  const StudentNotificationScreen({super.key, required this.studentId});

  @override
  State<StudentNotificationScreen> createState() => _StudentNotificationScreenState();
}

class _StudentNotificationScreenState extends State<StudentNotificationScreen> {
  final StudentService _studentService = StudentService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  /// Tải danh sách thông báo từ API.
  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final allNotifs = await _studentService.getNotifications();
      
      // Lọc theo receiverId == widget.studentId VÀ loại bỏ PAYMENT
      final filtered = allNotifs.where((n) {
        final rid = n['receiverId'] ?? n['receiver_id'];
        bool isForThisStudent = false;
        if (rid is int) isForThisStudent = rid == widget.studentId;
        if (rid is String) isForThisStudent = int.tryParse(rid) == widget.studentId;
        
        // Lọc bỏ PAYMENT notifications
        final notifType = (n['notificationType'] ?? n['notification_type'] ?? '').toString().toUpperCase();
        bool isNotPayment = notifType != 'PAYMENT';
        
        return isForThisStudent && isNotPayment;
      }).toList();

      if (mounted) {
        setState(() {
          _notifications = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Error fetching notifications
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Không có thông báo nào',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    // isRead: kiểm tra cả camelCase và snake_case
                    final rawIsRead = notification['isRead'] ?? notification['is_read'];
                    final isRead = rawIsRead == 1 || rawIsRead == true || rawIsRead == '1';
                    
                    // Get notification type
                    final notifType = (notification['notificationType'] ?? notification['notification_type'] ?? '').toString().toUpperCase();
                    
                    final title = notification['title'] ?? 'Thông báo';
                    final message = notification['message'] ?? '';
                    final sentAtRaw = notification['sentAt'];
                    
                    // Determine colors and icons based on notification type
                    Color bgColor;
                    Color iconBgColor;
                    Color iconColor;
                    Color textColor;
                    Color badgeBgColor;
                    Color badgeBorderColor;
                    Color badgeTextColor;
                    IconData icon;
                    String badgeLabel;
                    
                    if (notifType == 'WARNING' || notifType == 'ATTENDANCE') {
                      // WARNING and ATTENDANCE - Red theme
                      bgColor = isRead ? Colors.white : Colors.red.shade50;
                      iconBgColor = isRead ? Colors.red.shade100 : Colors.red.shade200;
                      iconColor = Colors.red.shade700;
                      textColor = Colors.red.shade700;
                      badgeBgColor = Colors.red;
                      badgeBorderColor = Colors.red.shade700;
                      badgeTextColor = Colors.white;
                      icon = notifType == 'ATTENDANCE' ? Icons.event_busy : Icons.warning_amber_rounded;
                      badgeLabel = notifType == 'ATTENDANCE' ? 'VẮNG HỌC' : 'CẢNH BÁO';
                    } else if (notifType == 'SYSTEM') {
                      // SYSTEM - Purple theme
                      bgColor = isRead ? Colors.white : Colors.purple.shade50;
                      iconBgColor = isRead ? Colors.purple.shade100 : Colors.purple.shade200;
                      iconColor = Colors.purple.shade700;
                      textColor = Colors.purple.shade700;
                      badgeBgColor = Colors.purple;
                      badgeBorderColor = Colors.purple.shade700;
                      badgeTextColor = Colors.white;
                      icon = Icons.info_outline;
                      badgeLabel = 'HỆ THỐNG';
                    } else {
                      // COMMENT or default - Blue theme
                      bgColor = isRead ? Colors.white : Colors.blue.shade50;
                      iconBgColor = isRead ? Colors.blue.shade100 : Colors.blue.shade200;
                      iconColor = Colors.blue.shade700;
                      textColor = Colors.blue.shade700;
                      badgeBgColor = Colors.blue;
                      badgeBorderColor = Colors.blue.shade700;
                      badgeTextColor = Colors.white;
                      icon = Icons.chat_bubble_outline;
                      badgeLabel = 'NHẬN XÉT';
                    }
                    
                    String senderName = 'Giáo viên';
                    String displayHeader = 'Bạn đã nhận được tin nhắn từ $senderName';
                    
                    String timeDisplay = '';
                    if (sentAtRaw != null) {
                      try {
                        final date = DateTime.parse(sentAtRaw);
                        timeDisplay = DateFormat('dd/MM/yyyy HH:mm').format(date);
                      } catch (_) {}
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: iconBgColor,
                              radius: 24,
                              child: Icon(
                                icon,
                                color: iconColor,
                                size: 24,
                              ),
                            ),
                            if (!isRead)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayHeader,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeBgColor,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: badgeBorderColor, width: 0.5),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: badgeTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 14,
                                color: isRead ? Colors.grey.shade700 : Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (timeDisplay.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                timeDisplay,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ],
                        ),
                        onTap: () async {
                          // Show detail bottom sheet
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => _NotificationDetailSheet(
                              notification: notification,
                              bgColor: bgColor,
                              iconColor: iconColor,
                              icon: icon,
                              badgeLabel: badgeLabel,
                              badgeBgColor: badgeBgColor,
                            ),
                          );
                          
                          // Mark as read after viewing
                          if (!isRead) {
                            final notificationId = notification['notificationId'] ?? notification['id'];
                            if (notificationId != null) {
                              await _studentService.markNotificationAsRead(notificationId);
                            }
                            setState(() {
                              notification['isRead'] = 1;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

/// Bottom sheet hiển thị chi tiết thông báo
class _NotificationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> notification;
  final Color bgColor;
  final Color iconColor;
  final IconData icon;
  final String badgeLabel;
  final Color badgeBgColor;

  const _NotificationDetailSheet({
    required this.notification,
    required this.bgColor,
    required this.iconColor,
    required this.icon,
    required this.badgeLabel,
    required this.badgeBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final title = notification['title'] ?? 'Thông báo';
    final message = notification['message'] ?? '';
    final sentAtRaw = notification['sentAt'];
    
    String timeDisplay = '';
    if (sentAtRaw != null) {
      try {
        final date = DateTime.parse(sentAtRaw);
        timeDisplay = DateFormat('dd/MM/yyyy HH:mm').format(date);
      } catch (_) {}
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chi tiết thông báo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBgColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Time
                  if (timeDisplay.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          timeDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                  ],
                  
                  // Message content
                  const Text(
                    'Nội dung:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message.isNotEmpty ? message : 'Không có nội dung',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Close button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Đóng',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
