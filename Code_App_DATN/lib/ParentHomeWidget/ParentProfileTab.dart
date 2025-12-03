import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../services/auth/auth_service.dart';
import '../services/parent/parent_service.dart';
import '../screens/parent/ParentNotificationScreen.dart';

/// Màn hình hồ sơ cá nhân dành cho Phụ huynh.
/// Cho phép xem, cập nhật thông tin cá nhân và đổi mật khẩu.
class ParentProfileTab extends StatefulWidget {
  final User user;
  final VoidCallback? onProfileUpdated;
  const ParentProfileTab({super.key, required this.user, this.onProfileUpdated});

  @override
  State<ParentProfileTab> createState() => ParentProfileTabState();
}

class ParentProfileTabState extends State<ParentProfileTab> {
  final AuthService _authService = AuthService();
  final ParentService _parentService = ParentService();
  
  bool _isLoading = true;
  Timer? _notificationTimer;
  int _unreadNotifications = 0;
  Map<String, dynamic>? _parentProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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

  /// Tải thông tin hồ sơ phụ huynh từ API.
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _parentService.getParentProfile();
      if (mounted) {
        setState(() {
          _parentProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi khi tải hồ sơ phụ huynh: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Tải lại dữ liệu
  Future<void> reload() async {
    await _loadProfile();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang tải lại hồ sơ...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// Xử lý đăng xuất.
  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () async {
                  // Cần ID học sinh hợp lệ để điều hướng đến ParentNotificationScreen
                  // Vì Profile không có con được chọn, thử tìm một hoặc dùng mặc định.
                  int studentId = widget.user.id ?? 0;
                  try {
                    final children = await _parentService.getChildren();
                    if (children.isNotEmpty) {
                      studentId = children.first['studentId'] ?? children.first['id'] ?? studentId;
                    }
                  } catch (e) {
                    // bỏ qua lỗi
                  }
                  
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParentNotificationScreen(studentId: studentId),
                      ),
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đăng xuất'),
                  content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _logout();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_parentProfile != null) {
                            _showUpdateProfileDialog();
                          }
                        },
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text('Cập nhật thông tin', style: TextStyle(color: Colors.white, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Hiển thị hộp thoại cập nhật thông tin cá nhân.
  Future<void> _showUpdateProfileDialog() async {
    final fullNameCtrl = TextEditingController(text: widget.user.fullName);
    final phoneCtrl = TextEditingController(text: widget.user.phone);
    final addressCtrl = TextEditingController(text: widget.user.address);
    final occupationCtrl = TextEditingController(text: _parentProfile!['occupation']);
    final idNumberCtrl = TextEditingController(text: _parentProfile!['idNumber']);
    bool isUpdating = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Cập nhật thông tin'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: fullNameCtrl,
                      decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'Địa chỉ', prefixIcon: Icon(Icons.location_on)),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: occupationCtrl,
                      decoration: const InputDecoration(labelText: 'Nghề nghiệp', prefixIcon: Icon(Icons.work)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: idNumberCtrl,
                      decoration: const InputDecoration(labelText: 'CCCD/CMND', prefixIcon: Icon(Icons.badge)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          setState(() => isUpdating = true);
                          
                          final Map<String, dynamic> updateData = {
                            'idNumber': idNumberCtrl.text.trim(),
                            'occupation': occupationCtrl.text.trim(),
                            'user': {
                              'fullName': fullNameCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                              'address': addressCtrl.text.trim(),
                              'email': widget.user.email, // Giữ nguyên email
                              'dob': widget.user.dob?.toIso8601String(), // Giữ nguyên ngày sinh
                              'gender': widget.user.gender.name.toUpperCase(), // Giữ nguyên giới tính
                            }
                          };

                          debugPrint('Đang cập nhật hồ sơ phụ huynh');

                          final success = await _parentService.updateParentProfile(
                            updateData
                          );

                          if (mounted) {
                            Navigator.of(ctx).pop();
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cập nhật thành công')),
                              );
                              _loadProfile();
                              widget.onProfileUpdated?.call();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cập nhật thất bại')),
                              );
                            }
                          }
                        },
                  child: isUpdating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Widget hiển thị phần header với avatar và tên.
  Widget _buildHeader() {
    final user = _parentProfile?['user'];
    final fullName = user?['fullName'] ?? widget.user.fullName ?? 'Phụ huynh';
    final contact = user?['email'] ?? user?['phone'] ?? widget.user.email ?? widget.user.phone ?? 'Chưa cập nhật email/SĐT';

    return Column(
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blueGrey,
          child: Icon(Icons.person, size: 60, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          fullName,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          contact,
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      ],
    );
  }

  /// Widget hiển thị thẻ thông tin chi tiết.
  Widget _buildInfoCard() {
    final user = _parentProfile?['user'];
    final dob = user?['dob'] ?? widget.user.dob?.toIso8601String();
    final gender = user?['gender'] ?? widget.user.gender.name;
    final address = user?['address'] ?? widget.user.address ?? 'Chưa cập nhật';
    final phone = user?['phone'] ?? widget.user.phone ?? 'Chưa cập nhật';

    String dobDisplay = 'Chưa cập nhật';
    if (dob != null) {
      try {
        final date = DateTime.parse(dob);
        dobDisplay = DateFormat('dd/MM/yyyy').format(date);
      } catch (_) {}
    }

    String genderDisplay = 'Chưa cập nhật';
    if (gender != null) {
      final g = gender.toString().toUpperCase();
      if (g == 'MALE' || g == 'NAM') genderDisplay = 'Nam';
      else if (g == 'FEMALE' || g == 'NU' || g == 'NỮ') genderDisplay = 'Nữ';
      else genderDisplay = 'Khác';
    }

    final occupation = _parentProfile?['occupation'] ?? 'Chưa cập nhật';
    final idNumber = _parentProfile?['idNumber'] ?? 'Chưa cập nhật';
    final childrenCount = _parentProfile?['childrenCount']?.toString() ?? '0';
    final isVerified = _parentProfile?['isVerified'] == true ? 'Đã xác thực' : 'Chưa xác thực';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin chi tiết',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow(Icons.cake, 'Ngày sinh', dobDisplay),
            _buildInfoRow(Icons.person_outline, 'Giới tính', genderDisplay),
            _buildInfoRow(Icons.phone, 'Số điện thoại', phone),
            _buildInfoRow(Icons.location_on, 'Địa chỉ', address),
            const Divider(),
            _buildInfoRow(Icons.work, 'Nghề nghiệp', occupation),
            _buildInfoRow(Icons.badge, 'CCCD/CMND', idNumber),
            _buildInfoRow(Icons.child_care, 'Số lượng con', '$childrenCount bé'),
            _buildInfoRow(Icons.verified_user, 'Trạng thái', isVerified, 
              valueColor: _parentProfile?['isVerified'] == true ? Colors.green : Colors.orange),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị một dòng thông tin.
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  value, 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? Colors.black87
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hiển thị hộp thoại đổi mật khẩu.
  Future<void> _showChangePasswordDialog() async {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Đổi mật khẩu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: oldPassCtrl,
                      decoration: const InputDecoration(labelText: 'Mật khẩu cũ'),
                      obscureText: true,
                    ),
                    TextField(
                      controller: newPassCtrl,
                      decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                      obscureText: true,
                    ),
                    TextField(
                      controller: confirmPassCtrl,
                      decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới'),
                      obscureText: true,
                    ),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final oldPass = oldPassCtrl.text;
                          final newPass = newPassCtrl.text;
                          final confirmPass = confirmPassCtrl.text;

                          setState(() => errorMessage = null);

                          if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                            setState(() => errorMessage = 'Vui lòng nhập đầy đủ thông tin');
                            return;
                          }

                          if (newPass.length < 6) {
                            setState(() => errorMessage = 'Mật khẩu mới phải có ít nhất 6 ký tự');
                            return;
                          }

                          if (newPass != confirmPass) {
                            setState(() => errorMessage = 'Mật khẩu mới không khớp');
                            return;
                          }

                          setState(() => isSubmitting = true);

                          try {
                            await _authService.changePassword(oldPass, newPass, confirmPass);
                            if (mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công')));
                            }
                          } catch (e) {
                            if (mounted) {
                                setState(() => errorMessage = e.toString().replaceAll("Exception: ", ""));
                            }
                          } finally {
                            if (mounted) setState(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Widget hiển thị thẻ cài đặt.
  Widget _buildSettingsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.blueGrey),
            title: const Text('Đổi mật khẩu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChangePasswordDialog,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.blueGrey),
            title: const Text('Trợ giúp & Phản hồi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chức năng đang phát triển')),
              );
            },
          ),
        ],
      ),
    );
  }
}
