import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import '../../services/parent/parent_service.dart';

class ParentNotificationScreen extends StatefulWidget {
  final int studentId;

  const ParentNotificationScreen({super.key, required this.studentId});

  @override
  State<ParentNotificationScreen> createState() => _ParentNotificationScreenState();
}

class _ParentNotificationScreenState extends State<ParentNotificationScreen> {
  final ParentService _parentService = ParentService();
  String _studentName = 'Học sinh';
  String _className = 'Nhà trường';
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  /// Tải dữ liệu thông báo và thông tin học sinh.
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchNotifications(),
      _fetchStudentInfo(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudentInfo() async {
    try {
      final data = await _parentService.getStudentDetail(widget.studentId);
      if (data != null) {
        final name = data['user']?['fullName'] ?? data['fullName'] ?? data['name'];
        
        String className = 'Nhà trường';
        final classes = data['studentClasses'] ?? data['classes'] ?? data['transcript'];
        if (classes is List && classes.isNotEmpty) {
          final firstClass = classes.first;
          if (firstClass is Map) {
            final clazz = firstClass['clazz'];
            if (clazz is Map) {
              className = clazz['name'] ?? clazz['code'] ?? 'Nhà trường';
            }
          }
        } else {
           // Fallback về khối lớp nếu không có lớp cụ thể
           if (data['gradeLevel'] != null) {
             className = 'Khối ${data['gradeLevel']}';
           }
        }

        if (mounted) {
          setState(() {
            if (name != null) _studentName = name;
            _className = className;
          });
        }
      }
    } catch (e) {
      // Error fetching student info
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final allNotifs = await _parentService.getNotifications();
      
      // Lọc theo receiverType == "PARENT" để hiển thị tất cả thông báo của phụ huynh
      final filtered = allNotifs.where((n) {
        final receiverType = (n['receiverType'] ?? n['receiver_type'] ?? '').toString().toUpperCase();
        return receiverType == 'PARENT';
      }).toList();

      // Sort by sentAt descending (newest first)
      filtered.sort((a, b) {
        final dateA = a['sentAt'] ?? '';
        final dateB = b['sentAt'] ?? '';
        return dateB.toString().compareTo(dateA.toString());
      });

      if (mounted) {
        setState(() {
          _notifications = filtered;
        });
      }
    } catch (e) {
      // Error fetching notifications
    }
  }

  /// Xử lý hành động thanh toán và refresh danh sách
  Future<void> _handlePaymentAction() async {
    // Refresh notifications after payment action
    await _fetchNotifications();
  }

  /// Xử lý xác nhận thanh toán
  Future<void> _confirmPayment(Map<String, dynamic> notification) async {
    final enrollmentId = notification['relatedEntityId'] ?? notification['related_entity_id'];
    if (enrollmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy thông tin đơn đăng ký')),
      );
      return;
    }

    try {
      final result = await _parentService.confirmEnrollmentPayment(enrollmentId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Đã xác nhận thanh toán'),
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          ),
        );
        
        if (result['success'] == true) {
          await _fetchNotifications(); // Refresh notifications
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
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
                    
                    // Debug: Print notification data

                    
                    // Check notification type
                    final notifType = (notification['notificationType'] ?? notification['notification_type'] ?? '').toString().toUpperCase();
                    final entityType = (notification['relatedEntityType'] ?? notification['related_entity_type'] ?? '').toString().toUpperCase();
                    final deliveryStatus = (notification['deliveryStatus'] ?? notification['delivery_status'] ?? '').toString().toUpperCase();
                    
                    final isPaymentNotif = notifType == 'PAYMENT' 
                        && entityType == 'ENROLLMENT' 
                        && deliveryStatus == 'PENDING';
                    final isWarningNotif = notifType == 'WARNING';
                    final isSystemNotif = notifType == 'SYSTEM';
                    
                    // isRead: kiểm tra cả camelCase và snake_case
                    final rawIsRead = notification['isRead'] ?? notification['is_read'];
                    final isRead = rawIsRead == 1 || rawIsRead == true || rawIsRead == '1';
                    
                    final title = notification['title'] ?? 'Thông báo';
                    final message = notification['message'] ?? '';
                    final sentAtRaw = notification['sentAt'];
                    
                    String displayHeader = '$_studentName nhận được tin nhắn từ $_className';
                    
                    String timeDisplay = '';
                    if (sentAtRaw != null) {
                      try {
                        final date = DateTime.parse(sentAtRaw);
                        timeDisplay = DateFormat('dd/MM/yyyy HH:mm').format(date);
                      } catch (_) {}
                    }

                    // Determine colors and icons based on type
                    Color backgroundColor;
                    Color iconBackgroundColor;
                    Color iconColor;
                    Color textColor;
                    IconData icon;
                    String? badge;
                    Color? badgeBgColor;
                    Color? badgeBorderColor;
                    Color? badgeTextColor;
                    
                    if (isPaymentNotif) {
                      backgroundColor = Colors.orange.shade50;
                      iconBackgroundColor = Colors.orange.shade100;
                      iconColor = Colors.orange.shade700;
                      textColor = Colors.orange.shade700;
                      icon = Icons.payment;
                      badge = 'THANH TOÁN';
                      badgeBgColor = Colors.orange.shade100;
                      badgeBorderColor = Colors.orange.shade300;
                      badgeTextColor = Colors.orange.shade800;
                    } else if (isWarningNotif) {
                      backgroundColor = isRead ? Colors.white : Colors.red.shade50;
                      iconBackgroundColor = Colors.red.shade100;
                      iconColor = Colors.red.shade700;
                      textColor = Colors.red.shade700;
                      icon = Icons.warning_amber_rounded;
                      badge = 'CẢNH BÁO';
                      badgeBgColor = Colors.red.shade100;
                      badgeBorderColor = Colors.red.shade300;
                      badgeTextColor = Colors.red.shade800;
                    } else if (isSystemNotif) {
                      backgroundColor = isRead ? Colors.white : Colors.green.shade50;
                      iconBackgroundColor = Colors.green.shade100;
                      iconColor = Colors.green.shade700;
                      textColor = Colors.green.shade700;
                      icon = Icons.info_outline;
                      badge = 'HỆ THỐNG';
                      badgeBgColor = Colors.green.shade100;
                      badgeBorderColor = Colors.green.shade300;
                      badgeTextColor = Colors.green.shade800;
                    } else {
                      // Default
                      backgroundColor = isRead ? Colors.white : Colors.blue.shade50;
                      iconBackgroundColor = isRead ? Colors.grey.shade200 : Colors.blue.shade100;
                      iconColor = isRead ? Colors.grey : Colors.blue;
                      textColor = Colors.blue.shade700;
                      icon = Icons.notifications;
                      badge = null;
                      badgeBgColor = null;
                      badgeBorderColor = null;
                      badgeTextColor = null;
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: iconBackgroundColor,
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Only show header for non-payment/warning/system notifications
                            if (!isPaymentNotif && !isWarningNotif && !isSystemNotif)
                              Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 4.0),
                                      child: Text(
                                        displayHeader,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                if (badge != null && badgeBgColor != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeBgColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: badgeBorderColor!),
                                    ),
                                    child: Text(
                                      badge,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: badgeTextColor,
                                      ),
                                    ),
                                  ),
                              ],
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
                              maxLines: 3,
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
                          // Show bottom sheet for all notifications
                          if (isPaymentNotif) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => _PaymentDetailSheet(
                                notification: notification,
                                onPaymentConfirmed: () => _handlePaymentAction(),
                              ),
                            );
                          } else {
                            // Show general notification detail sheet
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => _NotificationDetailSheet(
                                notification: notification,
                              ),
                            );
                            
                            // Mark as read for non-payment notifications
                            if (!isRead) {
                              final notificationId = notification['notificationId'] ?? notification['id'];
                              if (notificationId != null) {
                                final success = await _parentService.markNotificationAsRead(notificationId);
                                if (success && mounted) {
                                  setState(() {
                                    notification['isRead'] = 1;
                                  });
                                }
                              }
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

/// Widget bottom sheet hiển thị chi tiết thanh toán
class _PaymentDetailSheet extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onPaymentConfirmed;

  const _PaymentDetailSheet({
    required this.notification,
    required this.onPaymentConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final title = notification['title'] ?? 'Thông báo thanh toán';
    final message = notification['message'] ?? '';
    final shortMessage = notification['shortMessage'] ?? notification['short_message'] ?? '';
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.payment,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xác nhận thanh toán',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Đơn đăng ký mới',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
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

          // Payment Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Hướng dẫn thanh toán',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInstructionStep('1', 'Quý khách hãy đọc thật kĩ các thông tin trên'),
                const SizedBox(height: 8),
                _buildInstructionStep('2', 'Tiến hành chụp màn hình hoặc nhấn lưu mã QR'),
                const SizedBox(height: 8),
                _buildInstructionStep('3', 'Tiếp theo chuyển qua ứng dụng ngân hàng để thanh toán đúng với số tiền được yêu cầu'),
                const SizedBox(height: 8),
                _buildInstructionStep('4', 'Cuối cùng, quay lại đây và nhấn vào nút Xác nhận thanh toán'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Short message (if available)
                  if (shortMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              shortMessage,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // QR Code section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Quét mã QR để thanh toán',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              // Show fullscreen QR code
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Mã QR thanh toán',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.asset(
                                                'assets/images/qr_code.jpg',
                                                width: MediaQuery.of(context).size.width * 0.7,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          shape: const CircleBorder(),
                                          padding: const EdgeInsets.all(12),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.black),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade300,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/qr_code.jpg',
                                  width: 280,
                                  height: 280,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 280,
                                      height: 280,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.qr_code, size: 64, color: Colors.grey.shade400),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Không tìm thấy mã QR',
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhấn vào QR để phóng to',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Save QR button
                        ElevatedButton.icon(
                          onPressed: () => _saveQRCode(context),
                          icon: const Icon(Icons.download, size: 20),
                          label: const Text('Lưu mã QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Full message
                  const Text(
                    'Chi tiết:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Warning
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vui lòng kiểm tra kỹ thông tin trước khi xác nhận thanh toán. Sau khi xác nhận, bạn không thể hoàn tác.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Action buttons - only show if not yet read
          if (!((notification['isRead'] ?? notification['is_read']) == 1 || (notification['isRead'] ?? notification['is_read']) == true))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showCancelConfirmation(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Hủy đơn',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Confirm button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _showConfirmPaymentConfirmation(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Xác nhận thanh toán',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to build instruction step
  Widget _buildInstructionStep(String stepNumber, String instruction) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            instruction,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  void _saveQRCode(BuildContext context) async {
    try {
      // Load QR code image as bytes
      final ByteData bytes = await rootBundle.load('assets/images/qr_code.jpg');
      final buffer = bytes.buffer.asUint8List();
      
      // Save to gallery using gal package (auto handles permissions)
      await Gal.putImageBytes(buffer);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu mã QR vào thư viện ảnh'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Error saving QR code
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi lưu mã QR. Vui lòng chụp màn hình thay thế.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showConfirmPaymentConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thanh toán'),
        content: const Text(
          'Bạn xác nhận đã thanh toán cho đơn đăng ký này?\n\nSau khi xác nhận, hệ thống sẽ cập nhật trạng thái thanh toán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close bottom sheet
              _handleConfirmPayment(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _handleConfirmPayment(BuildContext context) async {
    // Mark notification as read
    final notificationId = notification['notificationId'] ?? notification['id'];
    if (notificationId != null) {
      final parentService = ParentService();
      await parentService.markNotificationAsRead(notificationId);
    }
    
    // Hiển thị thông báo thành công
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xác nhận thanh toán thành công'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Refresh danh sách thông báo để cập nhật UI
      onPaymentConfirmed();
    }
  }

  void _showCancelConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đơn đăng ký'),
        content: const Text(
          'Bạn có chắc chắn muốn hủy đơn đăng ký này?\n\nSau khi hủy, bạn sẽ không thể khôi phục lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close bottom sheet
              _handleCancelPayment(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );
  }

  void _handleCancelPayment(BuildContext context) async {
    final enrollmentId = notification['relatedEntityId'] ?? notification['related_entity_id'];
    if (enrollmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy thông tin đơn đăng ký')),
      );
      return;
    }

    try {
      // Mark notification as read
      final notificationId = notification['notificationId'] ?? notification['id'];
      if (notificationId != null) {
        final parentService = ParentService();
        await parentService.markNotificationAsRead(notificationId);
      }
      
      final parentService = ParentService();
      final result = await parentService.cancelEnrollmentPayment(enrollmentId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Đã hủy đơn đăng ký'),
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          ),
        );
        
        if (result['success'] == true) {
          onPaymentConfirmed(); // Refresh notifications
        }
      }
    } catch (e) {
      // Error canceling payment
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi hủy đơn: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

/// Widget bottom sheet hiển thị chi tiết thông báo chung (COMMENT, WARNING, SYSTEM)
class _NotificationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _NotificationDetailSheet({
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    final title = notification['title'] ?? 'Thông báo';
    final message = notification['message'] ?? '';
    final notifType = (notification['notificationType'] ?? notification['notification_type'] ?? '').toString().toUpperCase();
    
    // Determine type label and color
    String typeLabel = 'Thông báo';
    Color typeColor = Colors.blue;
    IconData typeIcon = Icons.notifications;
    
    if (notifType == 'COMMENT') {
      typeLabel = 'NHẬN XÉT';
      typeColor = Colors.orange;
      typeIcon = Icons.comment;
    } else if (notifType == 'WARNING') {
      typeLabel = 'CẢNH BÁO';
      typeColor = Colors.red;
      typeIcon = Icons.warning;
    } else if (notifType == 'SYSTEM') {
      typeLabel = 'HỆ THỐNG';
      typeColor = Colors.blue;
      typeIcon = Icons.info;
    }
    
    // Format timestamp
    String timeDisplay = '';
    try {
      final createdAt = notification['createdAt'] ?? notification['created_at'];
      if (createdAt != null) {
        final dateTime = DateTime.parse(createdAt.toString());
        timeDisplay = '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Header with icon and type
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: typeColor.withOpacity(0.1),
                        radius: 24,
                        child: Icon(typeIcon, color: typeColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: typeColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
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
                  const SizedBox(height: 20),
                  
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Message content
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                  
                  // Timestamp
                  if (timeDisplay.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          timeDisplay,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: typeColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Đóng',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
