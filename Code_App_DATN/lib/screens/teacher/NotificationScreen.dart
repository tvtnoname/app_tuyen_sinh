import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:app_quan_ly_tuyen_sinh/services/teacher/teacher_service.dart';

class AppNotificationScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? notifications;

  const AppNotificationScreen({super.key, this.notifications});

  @override
  State<AppNotificationScreen> createState() => _AppNotificationScreenState();
}

class _AppNotificationScreenState extends State<AppNotificationScreen> {
  final TeacherService _teacherService = TeacherService();
  final Map<int, Map<String, dynamic>> _studentDetails = {};
  final Map<int, String> _classNames = {}; // Ánh xạ classId sang className
  List<Map<String, dynamic>> _localNotifications = [];
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    if (widget.notifications != null) {
      _localNotifications = widget.notifications!;
    }
    _loadData();
  }

  /// Tải dữ liệu thông báo và thông tin liên quan (học sinh, lớp học).
  Future<void> _loadData() async {
    if (_localNotifications.isEmpty && widget.notifications == null) {
      await _fetchNotifications();
    }
    
    await Future.wait([
      _fetchStudentDetails(),
      _fetchClasses(),
    ]);
    if (mounted) {
      setState(() => _isLoadingDetails = false);
    }
  }

  /// Lấy danh sách thông báo từ API nếu chưa có.
  Future<void> _fetchNotifications() async {
    try {
      final allNotifs = await _teacherService.getNotifications();
      
      // Lọc chỉ thông báo SYSTEM cho giáo viên
      final systemNotifs = allNotifs.where((n) {
        final notifType = (n['notificationType'] ?? n['notification_type'] ?? '').toString().toUpperCase();
        return notifType == 'SYSTEM';
      }).toList();
      
      if (mounted) {
        setState(() {
          _localNotifications = systemNotifs;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  /// Lấy danh sách lớp học để hiển thị tên lớp.
  Future<void> _fetchClasses() async {
    try {
      final classes = await _teacherService.getTeacherClasses();
      for (var cls in classes) {
        final id = cls['classId'] ?? cls['id'];
        final name = cls['name'] ?? cls['className'];
        if (id != null && name != null) {
          if (id is int) {
            _classNames[id] = name.toString();
          } else if (id is String) {
            final parsed = int.tryParse(id);
            if (parsed != null) _classNames[parsed] = name.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching classes for notification screen: $e');
    }
  }

  /// Lấy thông tin chi tiết học sinh liên quan đến thông báo.
  Future<void> _fetchStudentDetails() async {
    final Set<int> studentIds = {};
    for (var n in _localNotifications) {
      // Kiểm tra receiverId (camelCase hoặc snake_case)
      var rid = n['receiverId'] ?? n['receiver_id'];
      if (rid != null && rid is int) {
        studentIds.add(rid);
      } else if (rid != null && rid is String) {
        final parsed = int.tryParse(rid);
        if (parsed != null) studentIds.add(parsed);
      }
    }

    if (studentIds.isEmpty) return;

    for (var id in studentIds) {
      try {
        final detail = await _teacherService.getStudentDetail(id);
        if (detail != null) {
          if (mounted) {
            setState(() {
              _studentDetails[id] = detail;
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching student $id: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        elevation: 0,
      ),
      body: _localNotifications.isEmpty
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
              itemCount: _localNotifications.length,
              itemBuilder: (context, index) {
                final notification = _localNotifications[index];
                // isRead: kiểm tra cả camelCase và snake_case, 1 hoặc true nghĩa là đã đọc
                final rawIsRead = notification['isRead'] ?? notification['is_read'];
                final isRead = rawIsRead == 1 || rawIsRead == true || rawIsRead == '1';
                
                final title = notification['title'] ?? 'Thông báo';
                final message = notification['message'] ?? '';
                final sentAtRaw = notification['sentAt'];
                
                // Cố gắng lấy thông tin học sinh

                var rid = notification['receiverId'] ?? notification['receiver_id'];
                int? studentId;
                if (rid is int) studentId = rid;
                else if (rid is String) studentId = int.tryParse(rid);

                // Cố gắng lấy thông tin lớp học từ thông báo trước

                String className = '';
                var cid = notification['classId'] ?? notification['class_id'];
                if (cid != null) {
                  int? classId;
                  if (cid is int) classId = cid;
                  else if (cid is String) classId = int.tryParse(cid);
                  
                  if (classId != null && _classNames.containsKey(classId)) {
                    className = _classNames[classId]!;
                  }
                }

                Map<String, dynamic>? studentInfo;
                if (studentId != null) {
                  studentInfo = _studentDetails[studentId];
                }

                String studentDisplayName = '';
                if (studentInfo != null) {
                  // Cố gắng lấy tên đầy đủ

                  String name = studentInfo['fullName'] ?? studentInfo['name'] ?? '';
                  if (name.isEmpty && studentInfo['user'] is Map) {
                    name = studentInfo['user']['fullName'] ?? '';
                  }
                  
                  // If class name not found in notification, try student details
                  if (className.isEmpty) {
                    // 1. Cố gắng tìm classId trong studentInfo và tra cứu trong _classNames

                    var studentClassId = studentInfo['classId'] ?? studentInfo['class_id'] ?? studentInfo['clazzId'];
                    if (studentClassId != null) {
                      int? scid;
                      if (studentClassId is int) scid = studentClassId;
                      else if (studentClassId is String) scid = int.tryParse(studentClassId);
                      
                      if (scid != null && _classNames.containsKey(scid)) {
                        className = _classNames[scid]!;
                      }
                    }

                    // 2. Fallback sang các trường tên trực tiếp nếu tra cứu thất bại

                    if (className.isEmpty) {
                      if (studentInfo['clazz'] is Map) {
                        className = studentInfo['clazz']['name'] ?? '';
                      } else if (studentInfo['className'] != null) {
                        className = studentInfo['className'];
                      } else if (studentInfo['class_name'] != null) {
                        className = studentInfo['class_name'];
                      } else if (studentInfo['class'] is Map) {
                        className = studentInfo['class']['name'] ?? '';
                      }
                    }

                    // 3. Cố gắng tìm tên lớp trong danh sách studentClasses

                    if (className.isEmpty && studentInfo['studentClasses'] is List) {
                      final sClasses = studentInfo['studentClasses'] as List;
                      if (sClasses.isNotEmpty) {
                        // Cố gắng tìm lớp khớp với classId của thông báo nếu có

                        var match;
                        // Sử dụng classId đã trích xuất trước đó từ thông báo

                        int? notifClassId;
                        if (cid != null) {
                           if (cid is int) notifClassId = cid;
                           else if (cid is String) notifClassId = int.tryParse(cid);
                        }

                        if (notifClassId != null) {
                           match = sClasses.firstWhere((sc) => sc is Map && (sc['classId'] == notifClassId || (sc['clazz'] is Map && sc['clazz']['classId'] == notifClassId)), orElse: () => null);
                        }
                        
                        // Nếu không có classId cụ thể trong thông báo hoặc không khớp, lấy cái đầu tiên

                        match ??= sClasses.firstWhere((sc) => sc is Map, orElse: () => null);

                        if (match != null && match is Map) {
                          if (match['clazz'] is Map) {
                            className = match['clazz']['name'] ?? '';
                          } else if (match['className'] != null) {
                            className = match['className'];
                          }
                        }
                      }
                    }
                  }

                  if (name.isNotEmpty) {
                    studentDisplayName = 'Bạn đã gửi nhận xét đến $name';
                    if (className.isNotEmpty) {
                      studentDisplayName += ', thuộc lớp $className';
                    }
                  }
                }
                
                String timeDisplay = '';
                if (sentAtRaw != null) {
                  try {
                    final date = DateTime.parse(sentAtRaw);
                    timeDisplay = DateFormat('dd/MM/yyyy HH:mm').format(date);
                  } catch (_) {}
                }

                return Container(
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.purple.shade50,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: isRead ? Colors.purple.shade100 : Colors.purple.shade200,
                          radius: 24,
                          child: Icon(
                            Icons.info_outline,
                            color: Colors.purple.shade700,
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
                                studentDisplayName.isNotEmpty ? studentDisplayName : 'Thông báo hệ thống',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.purple.shade700, width: 0.5),
                              ),
                              child: const Text(
                                'HỆ THỐNG',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
                        ),
                      );
                      
                      // Mark as read after viewing
                      if (!isRead) {
                        final id = notification['id'] ?? notification['notificationId'];
                        if (id != null) {
                          await _teacherService.markNotificationAsRead(id);
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

/// Bottom sheet hiển thị chi tiết thông báo cho giáo viên
class _NotificationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _NotificationDetailSheet({
    required this.notification,
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
              color: Colors.purple.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.info_outline, color: Colors.purple.shade700, size: 28),
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
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HỆ THỐNG',
                          style: TextStyle(
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
                  backgroundColor: Colors.purple,
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
