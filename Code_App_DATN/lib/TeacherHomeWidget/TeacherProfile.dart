import 'dart:async';
import 'dart:convert';
import 'package:app_quan_ly_tuyen_sinh/services/teacher/teacher_service.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/teacher/NotificationScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class TeacherProfile extends StatefulWidget {
  final User user;
  final VoidCallback? onProfileUpdated;
  const TeacherProfile({super.key, required this.user, this.onProfileUpdated});

  @override
  State<TeacherProfile> createState() => TeacherProfileState();
}

class TeacherProfileState extends State<TeacherProfile> {
  final TeacherService _teacherService = TeacherService();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isPatching = false;
  Map<String, dynamic>? _teacherData;

  // Khởi tạo các controller để quản lý dữ liệu trong hộp thoại chỉnh sửa.

  late TextEditingController _fullNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  String? _gender;
  DateTime? _dob;

  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadTeacherProfile();
    _startNotificationTimer();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
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

  void _initializeControllers() {
    _fullNameCtrl = TextEditingController(text: widget.user.fullName ?? '');
    _emailCtrl = TextEditingController(text: widget.user.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
    _addressCtrl = TextEditingController(text: widget.user.address ?? '');
    _gender = _convertGenderToString(widget.user.gender);
    _dob = widget.user.dob;
  }

  String? _convertGenderToString(dynamic gender) {
    if (gender == null) return null;
    final genderStr = gender.toString().toUpperCase();
    if (genderStr.contains('MALE')) return 'MALE';
    if (genderStr.contains('FEMALE')) return 'FEMALE';
    return null;
  }

  // Phương thức reload công khai để hỗ trợ tính năng làm mới bằng thao tác chạm hai lần.

  Future<void> reload() async {
    await _loadTeacherProfile();
  }

  int _unreadCount = 0;

  Future<void> _loadTeacherProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final profile = await _teacherService.getTeacherProfile();
      
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
          _teacherData = profile;
          _isLoading = false;
          
          // Cập nhật giá trị cho các controller dựa trên dữ liệu hồ sơ đã tải.

          if (_teacherData != null) {
            final userData = _teacherData!['user'];
            if (userData != null) {
              _fullNameCtrl.text = userData['fullName'] ?? widget.user.fullName ?? '';
              _emailCtrl.text = userData['email'] ?? widget.user.email ?? '';
              _phoneCtrl.text = userData['phone'] ?? widget.user.phone ?? '';
              _addressCtrl.text = userData['address'] ?? widget.user.address ?? '';
              _gender = _convertGenderToString(userData['gender'] ?? widget.user.gender);
              if (userData['dob'] != null) {
                try {
                  _dob = DateTime.parse(userData['dob'].toString());
                } catch (_) {}
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final DateTime dt = DateTime.parse(date.toString());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return date.toString();
    }
  }

  String _formatGender(dynamic gender) {
    if (gender == null) return 'N/A';
    
    // Xử lý trường hợp giới tính là Enum.

    if (gender.toString().contains('Gender.')) {
      final genderStr = gender.toString().split('.').last.toUpperCase();
      switch (genderStr) {
        case 'MALE':
          return 'Nam';
        case 'FEMALE':
          return 'Nữ';
        default:
          return 'Không xác định';
      }
    }
    
    // Xử lý trường hợp giới tính là chuỗi ký tự.

    final genderStr = gender.toString().toUpperCase();
    switch (genderStr) {
      case 'MALE':
        return 'Nam';
      case 'FEMALE':
        return 'Nữ';
      default:
        return gender.toString();
    }
  }

  Future<void> _pickDob() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _showEditDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (c, setDialogState) {
          return AlertDialog(
            title: const Text('Cập nhật thông tin'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: _fullNameCtrl, decoration: const InputDecoration(labelText: 'Họ và tên')),
                  TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                  TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Số điện thoại'), keyboardType: TextInputType.phone),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _gender,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Giới tính')),
                            DropdownMenuItem(value: 'MALE', child: Text('Nam')),
                            DropdownMenuItem(value: 'FEMALE', child: Text('Nữ')),
                          ],
                          onChanged: (v) => setDialogState(() => _gender = v),
                          decoration: const InputDecoration(labelText: 'Giới tính'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final prev = _dob;
                            await _pickDob();
                            setDialogState(() {});
                            if (_dob == prev) setDialogState(() {});
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Ngày sinh'),
                            child: Text(_dob != null ? DateFormat('dd/MM/yyyy').format(_dob!) : 'Chọn ngày'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Địa chỉ')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: _isPatching
                    ? null
                    : () async {
                  Navigator.of(ctx).pop();
                  await _patchProfile();
                },
                child: _isPatching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _patchProfile() async {
    final fullName = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final dobStr = _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : null;

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập họ và tên')));
      return;
    }

    setState(() => _isPatching = true);

    try {
      String apiBase = _authService.baseUrl;
      if (apiBase.endsWith('/api/auth')) apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);

      final String url = '$apiBase/api/teacher';
      final token = await _authService.getToken();
      final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final Map<String, dynamic> body = {
        'user': {
          'fullName': fullName,
          if (email.isNotEmpty) 'email': email,
          if (phone.isNotEmpty) 'phone': phone,
          if (_gender != null) 'gender': _gender,
          if (dobStr != null) 'dob': dobStr,
          if (address.isNotEmpty) 'address': address,
        },
        'teacher': {
          'updateAt': DateTime.now().toIso8601String()
        }
      };

      final resp = await http.patch(Uri.parse(url), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 12));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        // Cập nhật lạc quan (Optimistic Update): Cập nhật giao diện ngay lập tức với dữ liệu từ form.

        if (mounted) {
          setState(() {
            // Cập nhật biến _teacherData với các giá trị mới để phản ánh ngay lên giao diện.

            if (_teacherData != null && _teacherData!['user'] != null) {
              _teacherData!['user']['fullName'] = fullName;
              if (email.isNotEmpty) _teacherData!['user']['email'] = email;
              if (phone.isNotEmpty) _teacherData!['user']['phone'] = phone;
              if (_gender != null) _teacherData!['user']['gender'] = _gender;
              if (dobStr != null) _teacherData!['user']['dob'] = dobStr;
              if (address.isNotEmpty) _teacherData!['user']['address'] = address;
            }
          });
        }
        
        // Sau đó tải lại dữ liệu từ máy chủ để đảm bảo tính đồng bộ và chính xác.

        await _loadTeacherProfile();
        
        // Thông báo cho widget cha để làm mới dữ liệu người dùng trên toàn bộ ứng dụng.

        widget.onProfileUpdated?.call();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thông tin thành công')));
        }
      } else {
        String msg = 'Cập nhật thất bại: ${resp.statusCode}';
        try {
          final Map<String, dynamic> j = jsonDecode(resp.body);
          msg = j['message'] ?? j['msg'] ?? msg;
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      debugPrint('Patch profile error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi cập nhật: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPatching = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Hồ sơ giáo viên'),
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
                  ).then((_) => _loadTeacherProfile());
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
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Xác nhận đăng xuất'),
                    content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Hủy'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await _authService.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Hiển thị phần đầu trang hồ sơ.

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              (widget.user.fullName ?? 'T').substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.user.fullName ?? widget.user.userName ?? 'Giáo viên',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _teacherData?['code'] ?? 'N/A',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hiển thị phần thông tin cá nhân.

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông tin cá nhân',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            Icons.person,
                            'Họ và tên',
                            _teacherData?['user']?['fullName'] ?? widget.user.fullName ?? 'N/A',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.wc,
                            'Giới tính',
                            _formatGender(_teacherData?['user']?['gender'] ?? widget.user.gender),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.cake,
                            'Ngày sinh',
                            _formatDate(_teacherData?['user']?['dob'] ?? widget.user.dob),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.location_on,
                            'Địa chỉ',
                            _teacherData?['user']?['address'] ?? widget.user.address ?? 'N/A',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hiển thị phần thông tin liên hệ.

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông tin liên hệ',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(Icons.email, 'Email', widget.user.email ?? 'N/A'),
                          const SizedBox(height: 12),
                          _buildInfoRow(Icons.phone, 'Số điện thoại', widget.user.phone ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hiển thị phần thông tin nghề nghiệp.

                  if (_teacherData != null) ...[
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thông tin nghề nghiệp',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              Icons.school,
                              'Trình độ',
                              _teacherData!['qualification'] ?? 'N/A',
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.work,
                              'Kinh nghiệm',
                              '${_teacherData!['experienceYears'] ?? 0} năm',
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.confirmation_number,
                              'Mã giáo viên',
                              _teacherData!['code'] ?? 'N/A',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Hiển thị các nút hành động (Cập nhật, Đổi mật khẩu).

                  ElevatedButton.icon(
                    onPressed: _isPatching ? null : _showEditDialog,
                    icon: const Icon(Icons.edit),
                    label: Text(_isPatching ? 'Đang cập nhật...' : 'Cập nhật thông tin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showChangePasswordDialog,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Đổi mật khẩu'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
