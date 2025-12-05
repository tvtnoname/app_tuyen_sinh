import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../models/user.dart';
import '../../services/auth/auth_service.dart';
import '../../services/student/registered_courses_service.dart';
import '../../services/student/student_service.dart';
import '../../screens/student/StudentNotificationScreen.dart';

const List<String> schoolOptions = [
  'Trường THCS Đoàn Thị Điểm',
  'THPT Nguyễn Hữu Cầu',
  'Trường THCS Nguyễn Du',
  'Trường THPT Mạc Đĩnh Chi',
  'Trường THCS Bạch Đằng',
  'Trường THPT Lê Quý Đôn',
  'Trường THCS Á Châu',
  'Trường THPT Trần Phú',
  'Trường THCS Việt Úc',
  'Trường THPT Phú Nhuận',
  'Trường THCS Trần Văn Ơn',
  'Trường THPT Bùi Thị Xuân',
  'Trường THCS Hai Bà Trưng',
  'Trường THPT Nguyễn Hữu Huân',
  'Trường THCS Nguyễn Hữu Thọ',
  'Trường THPT Nguyễn Thị Minh Khai',
  'Trường THCS Colette',
  'Trường THPT Gia Định',
  'Trường THCS Lê Quý Đôn',
  'Trường THPT Nguyễn Thượng Hiền',
  'Trường khác',
];

class Profile extends StatefulWidget {
  final User user;
  final VoidCallback? onProfileUpdated;
  const Profile({super.key, required this.user, this.onProfileUpdated});

  @override
  State<Profile> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<Profile> {
  final AuthService _authService = AuthService();
  final StudentService _studentService = StudentService();
  int _unreadNotifications = 0;
  Timer? _notificationTimer;

  // Bản sao dữ liệu người dùng để chỉnh sửa (tránh sửa đổi trực tiếp widget.user)

  late Map<String, dynamic> _currentUserMap;

  @override
  void initState() {
    super.initState();
    _loadUnreadNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadUnreadNotifications();
    });
    // Chuyển đổi đối tượng User sang Map

    try {
      _currentUserMap = (widget.user.toJson()).map((k, v) => MapEntry(k, v));
    } catch (_) {
    // Dự phòng: Tạo Map thủ công nếu chuyển đổi thất bại
      _currentUserMap = {
        'id': (widget.user as dynamic).id ?? null,
        'userName': widget.user.userName,
        'fullName': widget.user.fullName,
        'email': widget.user.email,
        'phone': widget.user.phone,
        'address': widget.user.address,
        'dob': widget.user.dob != null ? DateFormat('yyyy-MM-dd').format(widget.user.dob!) : null,
        'gender': widget.user.gender == Gender.male ? 'MALE' : (widget.user.gender == Gender.female ? 'FEMALE' : null),
        'avatarUrl': widget.user.avatarUrl,
        'role': widget.user.role,
        'schoolName': widget.user.schoolName,
      };
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final allNotifs = await _studentService.getNotifications();
      // Lọc theo receiverId == widget.user.id VÀ loại bỏ PAYMENT

      final myNotifs = allNotifs.where((n) {
        final rid = n['receiverId'] ?? n['receiver_id'];
        bool isForMe = false;
        if (rid is int) isForMe = rid == widget.user.id;
        if (rid is String) isForMe = int.tryParse(rid) == widget.user.id;
        
        // Lọc bỏ PAYMENT notifications
        final notifType = (n['notificationType'] ?? n['notification_type'] ?? '').toString().toUpperCase();
        bool isNotPayment = notifType != 'PAYMENT';
        
        return isForMe && isNotPayment;
      }).toList();

      final unreadCount = myNotifs.where((notif) {
        final rawIsRead = notif['isRead'] ?? notif['is_read'];
        final isRead = rawIsRead == 1 || rawIsRead == true || rawIsRead == '1';
        return !isRead;
      }).length;

      if (mounted) {
        setState(() {
          _unreadNotifications = unreadCount;
        });
      }
    } catch (e) {
      debugPrint("Error loading unread notifications: $e");
    }
  }

  // Cập nhật dữ liệu cục bộ và làm mới giao diện
  void _applyUpdatedFields(Map<String, dynamic> updated) {
    setState(() {
      updated.forEach((k, v) {
        _currentUserMap[k] = v;
      });
    });
    // Tải lại dữ liệu từ server và thông báo cập nhật
    reload();
  }

  Future<void> reload() async {
    final newUser = await _authService.fetchProfile();
    if (newUser != null && mounted) {
      setState(() {
        try {
          _currentUserMap = (newUser.toJson()).map((k, v) => MapEntry(k, v));
        } catch (_) {
           // Xử lý dự phòng nếu cấu trúc dữ liệu không khớp
           _currentUserMap['fullName'] = newUser.fullName;
           _currentUserMap['email'] = newUser.email;
           _currentUserMap['phone'] = newUser.phone;
           _currentUserMap['address'] = newUser.address;
           _currentUserMap['avatarUrl'] = newUser.avatarUrl;
           _currentUserMap['schoolName'] = newUser.schoolName;
        }
      });
      widget.onProfileUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: Column(
          children: [
            _buildProfileHeader(context),
            Container(
              color: Colors.white,
              child: const TabBar(
                isScrollable: true,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                tabs: [
                  Tab(text: 'Thông tin'),
                  Tab(text: 'Kết quả học tập'),
                  Tab(text: 'Chuyên cần'),
                  Tab(text: 'Hóa đơn'),
                  Tab(text: 'Phản hồi'),
                  Tab(text: 'Cảnh báo'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab thông tin cá nhân: Cho phép chỉnh sửa và cập nhật dữ liệu


                  PersonalInfoTab(
                    currentUserMap: _currentUserMap,
                    onPatched: (updatedFields) {
                      _applyUpdatedFields(updatedFields);
                    },
                  ),
                  const GradesTab(),
                  const AttendanceTab(),
                  BillingTab(user: widget.user),
                  FeedbackTab(user: widget.user),
                  WarningTab(user: widget.user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final displayName = (_currentUserMap['fullName'] as String?) ??
        (_currentUserMap['userName'] as String?) ??
        widget.user.userName ??
        'N/A';
    final role = (_currentUserMap['role'] as String?) ?? widget.user.role ?? 'Học sinh';
    final avatarUrl = (_currentUserMap['avatarUrl'] as String?) ?? widget.user.avatarUrl;

    ImageProvider avatarImage;
    if (avatarUrl != null && (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))) {
      avatarImage = NetworkImage(avatarUrl);
    } else {
      avatarImage = AssetImage(avatarUrl?.isNotEmpty == true ? avatarUrl! : 'assets/images/avatar.jpg');
    }

    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 40, backgroundImage: avatarImage),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(role, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentNotificationScreen(studentId: widget.user.id ?? 0),
                    ),
                  ).then((_) => _loadUnreadNotifications());
                },
                icon: const Icon(Icons.notifications_outlined, size: 28, color: Colors.blueGrey),
                tooltip: 'Thông báo',
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadNotifications.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
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
                    content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    actions: <Widget>[
                      TextButton(child: const Text('Hủy', style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.of(dialogContext).pop()),
                      TextButton(
                        child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          await _authService.logout();
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 28),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
    );
  }
}

/// PersonalInfoTab: Quản lý và cập nhật thông tin cá nhân


class PersonalInfoTab extends StatefulWidget {
  final Map<String, dynamic> currentUserMap;
  final void Function(Map<String, dynamic> updatedFields)? onPatched;

  const PersonalInfoTab({super.key, required this.currentUserMap, this.onPatched});

  @override
  State<PersonalInfoTab> createState() => _PersonalInfoTabState();
}

class _PersonalInfoTabState extends State<PersonalInfoTab> {
  late TextEditingController _fullNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  DateTime? _dob;
  String? _gender;
  String? _schoolName;
  bool _isPatching = false;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    final m = widget.currentUserMap;
    _fullNameCtrl = TextEditingController(text: (m['fullName'] ?? m['userName'])?.toString() ?? '');
    _emailCtrl = TextEditingController(text: (m['email'] ?? '')?.toString() ?? '');
    _phoneCtrl = TextEditingController(text: (m['phone'] ?? '')?.toString() ?? '');
    _addressCtrl = TextEditingController(text: (m['address'] ?? '')?.toString() ?? '');
    final dobRaw = m['dob'] ?? m['dateOfBirth'] ?? m['birthDate'];
    if (dobRaw != null) {
      try {
        _dob = DateTime.tryParse(dobRaw.toString());
      } catch (_) {
        _dob = null;
      }
    }
    final g = (m['gender'] ?? '').toString().toUpperCase();
    if (g == 'MALE' || g == 'M') _gender = 'MALE';
    else if (g == 'FEMALE' || g == 'F') _gender = 'FEMALE';
    else _gender = null;
    _schoolName = m['schoolName']?.toString();
  }

  @override
  void didUpdateWidget(PersonalInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentUserMap != oldWidget.currentUserMap) {
      final m = widget.currentUserMap;
      _fullNameCtrl.text = (m['fullName'] ?? m['userName'])?.toString() ?? '';
      _emailCtrl.text = (m['email'] ?? '')?.toString() ?? '';
      _phoneCtrl.text = (m['phone'] ?? '')?.toString() ?? '';
      _addressCtrl.text = (m['address'] ?? '')?.toString() ?? '';
      
      final dobRaw = m['dob'] ?? m['dateOfBirth'] ?? m['birthDate'];
      if (dobRaw != null) {
        try {
          _dob = DateTime.tryParse(dobRaw.toString());
        } catch (_) {
          _dob = null;
        }
      }
      
      final g = (m['gender'] ?? '').toString().toUpperCase();
      if (g == 'MALE' || g == 'M') _gender = 'MALE';
      else if (g == 'FEMALE' || g == 'F') _gender = 'FEMALE';
      else _gender = null;
      
      _schoolName = m['schoolName']?.toString();
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  String _formatDob() {
    if (_dob != null) {
      try {
        return DateFormat('dd/MM/yyyy').format(_dob!);
      } catch (_) {}
    }
    final pDob = widget.currentUserMap['dob'] ?? widget.currentUserMap['dateOfBirth'];
    return pDob?.toString() ?? 'N/A';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 10);
    final dt = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1900), lastDate: now);
    if (dt != null) setState(() => _dob = dt);
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
                          child: InputDecorator(decoration: const InputDecoration(labelText: 'Ngày sinh'), child: Text(_dob != null ? DateFormat('dd/MM/yyyy').format(_dob!) : 'Chọn ngày')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: schoolOptions.contains(_schoolName) ? _schoolName : null,
                    isExpanded: true,
                    items: schoolOptions.map((school) {
                      return DropdownMenuItem(
                        value: school,
                        child: Text(school, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => _schoolName = v),
                    decoration: const InputDecoration(labelText: 'Tên trường'),
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

  // Cập nhật thông tin hồ sơ lên server



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
      String apiBase = _auth_service_baseUrl();
      if (apiBase.endsWith('/api/auth')) apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);

      // Gọi API cập nhật thông tin học sinh


      final String url = '$apiBase/api/student';

      final token = await _auth_service_getToken();
      final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      // Chuẩn bị dữ liệu cập nhật


      final Map<String, dynamic> body = {
        if (_schoolName != null) 'schoolName': _schoolName,
        'user': {
          'fullName': fullName,
          if (email.isNotEmpty) 'email': email,
          if (phone.isNotEmpty) 'phone': phone,
          if (_gender != null) 'gender': _gender,
          if (dobStr != null) 'dob': dobStr,
          if (address.isNotEmpty) 'address': address,
        },
        // Các trường khác nếu cần thiết có thể thêm vào root hoặc user tùy API
        // Dựa trên Postman: schoolName ở root, user chứa thông tin cá nhân
      };

      final resp = await http.patch(Uri.parse(url), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 12));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        // Cập nhật giao diện ngay lập tức (Optimistic UI)


        final optimisticData = {
          'fullName': fullName,
          if (email.isNotEmpty) 'email': email,
          if (phone.isNotEmpty) 'phone': phone,
          if (_gender != null) 'gender': _gender,
          if (dobStr != null) 'dob': dobStr,
          if (address.isNotEmpty) 'address': address,
          if (_schoolName != null) 'schoolName': _schoolName,
        };
        widget.onPatched?.call(optimisticData);

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi cập nhật: $e')));
    } finally {
      if (mounted) setState(() => _isPatching = false);
    }
  }

  Future<String?> _auth_service_getToken() async {
    try {
      return await _authService.getToken();
    } catch (_) {
      return null;
    }
  }

  String _auth_service_baseUrl() {
    var apiBase = _authService.baseUrl;
    return apiBase;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _InfoCard(
          title: 'Thông tin cá nhân',
          children: [
            _InfoRow(icon: Icons.person_outline, label: 'Họ và tên', value: (widget.currentUserMap['fullName'] ?? widget.currentUserMap['userName'] ?? 'N/A').toString()),
            _InfoRow(icon: Icons.cake_outlined, label: 'Ngày sinh', value: _formatDob()),
            _InfoRow(icon: Icons.wc_outlined, label: 'Giới tính', value: ((widget.currentUserMap['gender'] ?? '') == 'MALE') ? 'Nam' : (((widget.currentUserMap['gender'] ?? '') == 'FEMALE') ? 'Nữ' : 'N/A')),
            _InfoRow(icon: Icons.school_outlined, label: 'Trường', value: (widget.currentUserMap['schoolName'] ?? 'Chưa cập nhật').toString()),
          ],
        ),
        _InfoCard(
          title: 'Thông tin liên hệ',
          children: [
            _InfoRow(icon: Icons.email_outlined, label: 'Email', value: (widget.currentUserMap['email'] ?? 'N/A').toString()),
            _InfoRow(icon: Icons.phone_outlined, label: 'Số điện thoại', value: (widget.currentUserMap['phone'] ?? 'N/A').toString()),
            _InfoRow(icon: Icons.location_on_outlined, label: 'Địa chỉ', value: (widget.currentUserMap['address'] ?? 'N/A').toString()),
          ],
        ),
        const SizedBox(height: 16),
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
          style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ],
    );
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
}

/// Tab 2: Kết quả học tập
class GradesTab extends StatefulWidget {
  const GradesTab({super.key});

  @override
  State<GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<GradesTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _currentCourses = [];
  List<Map<String, dynamic>> _completedCourses = [];
  int? _selectedSemesterId;

  final RegisteredCoursesService _courseService = RegisteredCoursesService();
  final StudentService _studentService = StudentService();

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  bool _isCourseActive(Map<String, dynamic> course) {
    var endDateStr = course['endDate']?.toString();
    if (endDateStr == null || endDateStr.isEmpty) return true;

    endDateStr = endDateStr.trim();
    try {
      DateTime? endDate;
      try {
        endDate = DateTime.parse(endDateStr);
      } catch (_) {
        try {
          endDate = DateFormat('dd/MM/yyyy').parse(endDateStr);
        } catch (_) {
           try {
             endDate = DateFormat('dd-MM-yyyy').parse(endDateStr);
           } catch (_) {}
        }
      }

      if (endDate == null) return true;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      
      // Nếu ngày kết thúc nhỏ hơn ngày hiện tại -> Đã kết thúc
      return !end.isBefore(today);
    } catch (e) {
      return true;
    }
  }

  Future<void> _loadGrades() async {
    try {
      final courses = await _courseService.getCourses();
      final current = <Map<String, dynamic>>[];
      final completed = <Map<String, dynamic>>[];

      for (final c in courses) {
        if (_isCourseActive(c)) {
          current.add(c);
        } else {
          completed.add(c);
        }
      }

      // Tải thông báo để lấy nhận xét của giáo viên (giữ nguyên logic cũ)
      try {
        final notifications = await _studentService.getNotifications();
        final studentClassIds = <int>{};
        for (var c in current) {
          final cid = c['classId'];
          if (cid is int) studentClassIds.add(cid);
          else if (cid is String) {
            final parsed = int.tryParse(cid);
            if (parsed != null) studentClassIds.add(parsed);
          }
        }
        for (var c in completed) {
          final cid = c['classId'];
          if (cid is int) studentClassIds.add(cid);
          else if (cid is String) {
            final parsed = int.tryParse(cid);
            if (parsed != null) studentClassIds.add(parsed);
          }
        }
        
        for (final notif in notifications) {
          final notificationType = (notif['notificationType'] ?? notif['notification_type'] ?? '').toString().toUpperCase();
          if (notificationType == 'WARNING') {
            final message = notif['message'];
            final senderId = notif['senderId'] ?? notif['sender_id'];
            if (senderId != null && message != null) {
              int? teacherId;
              if (senderId is int) teacherId = senderId;
              else if (senderId is String) teacherId = int.tryParse(senderId);
              
              if (teacherId != null) {
                try {
                  final teacherInfo = await _studentService.getTeacherInfo(teacherId);
                  if (teacherInfo != null && teacherInfo['teachingAssignments'] is List) {
                    final assignments = teacherInfo['teachingAssignments'] as List;
                    String? teacherName;
                    if (teacherInfo['user'] is Map) {
                      final user = teacherInfo['user'] as Map;
                      teacherName = user['fullName']?.toString() ?? user['userName']?.toString();
                    }
                    final matchedClassIds = <int>[];
                    for (var assignment in assignments) {
                      if (assignment is Map) {
                        final classId = assignment['classId'];
                        int? cid;
                        if (classId is int) cid = classId;
                        else if (classId is String) cid = int.tryParse(classId);
                        if (cid != null && studentClassIds.contains(cid)) matchedClassIds.add(cid);
                      }
                    }
                    final commentWithTeacher = teacherName != null ? 'GV: $teacherName - $message' : message;
                    for (var cid in matchedClassIds) {
                      // Add comment to list instead of overwriting
                      for (var c in current) {
                        final courseClassId = c['classId'];
                        int? ccid;
                        if (courseClassId is int) ccid = courseClassId;
                        else if (courseClassId is String) ccid = int.tryParse(courseClassId);
                        if (ccid == cid) {
                          if (c['teacherComments'] == null) {
                            c['teacherComments'] = <String>[];
                          }
                          if (c['teacherComments'] is List && !c['teacherComments'].contains(commentWithTeacher)) {
                            c['teacherComments'].add(commentWithTeacher);
                          }
                        }
                      }
                      for (var c in completed) {
                        final courseClassId = c['classId'];
                        int? ccid;
                        if (courseClassId is int) ccid = courseClassId;
                        else if (courseClassId is String) ccid = int.tryParse(courseClassId);
                        if (ccid == cid) {
                          if (c['teacherComments'] == null) {
                            c['teacherComments'] = <String>[];
                          }
                          if (c['teacherComments'] is List && !c['teacherComments'].contains(commentWithTeacher)) {
                            c['teacherComments'].add(commentWithTeacher);
                          }
                        }
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('Error fetching teacher info: $e');
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching comments from notifications: $e');
      }

      if (mounted) {
        setState(() {
          _currentCourses = current;
          _completedCourses = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading grades: $e');
      if (mounted) {
        setState(() {
          _currentCourses = [];
          _completedCourses = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getAvailableSemesters(List<Map<String, dynamic>> courses) {
    final Map<int, String> semesters = {};
    for (var course in courses) {
      if (course['semester'] is Map) {
        final id = course['semester']['id'];
        final name = course['semester']['name'];
        if (id != null && name != null) {
          semesters[id] = name;
        }
      }
    }
    return semesters.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  void _showGradeDetails(BuildContext context, Map<String, dynamic> courseData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return _GradeDetailSheet(courseData: courseData);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    // Lọc khóa học đã học theo học kỳ
    final filteredCompletedCourses = _selectedSemesterId == null
        ? _completedCourses
        : _completedCourses.where((c) => c['semester'] is Map && c['semester']['id'] == _selectedSemesterId).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: [
                Tab(text: 'Đang học'),
                Tab(text: 'Đã học'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Đang học
                ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (_currentCourses.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.only(top: 20), child: Text('Không có khóa học nào đang học'))),
                    ..._currentCourses.map((course) {
                      return _GradeItem(
                        subject: course['subject'],
                        grade: course['grade'].toString(),
                        semester: course['semester'] is Map ? course['semester']['name'] : null,
                        endDate: course['endDate'],
                        onTap: () => _showGradeDetails(context, course),
                      );
                    }).toList(),
                  ],
                ),
                
                // Tab 2: Đã học (có filter)
                Column(
                  children: [
                    // Filter Bar
                    if (_completedCourses.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.grey[50],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Lọc theo học kỳ:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isDense: true,
                                  hint: const Text('Tất cả', style: TextStyle(fontSize: 13)),
                                  value: _selectedSemesterId,
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('Tất cả', style: TextStyle(fontSize: 13)),
                                    ),
                                    ..._getAvailableSemesters(_completedCourses).map((sem) {
                                      return DropdownMenuItem<int>(
                                        value: sem['id'],
                                        child: Text(sem['name'], style: const TextStyle(fontSize: 13)),
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
                        ),
                      ),
                    
                    // List
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          if (filteredCompletedCourses.isEmpty)
                            const Center(child: Padding(padding: EdgeInsets.only(top: 20), child: Text('Không có khóa học nào'))),
                          ...filteredCompletedCourses.map((course) {
                            return _GradeItem(
                              subject: course['subject'],
                              grade: course['grade'].toString(),
                              semester: course['semester'] is Map ? course['semester']['name'] : null,
                              endDate: course['endDate'],
                              onTap: () => _showGradeDetails(context, course),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab 3: Chuyên cần
class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _currentCourses = [];
  List<Map<String, dynamic>> _completedCourses = [];
  int? _selectedSemesterId;

  final RegisteredCoursesService _courseService = RegisteredCoursesService();

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  bool _isCourseActive(Map<String, dynamic> course) {
    var endDateStr = course['endDate']?.toString();
    if (endDateStr == null || endDateStr.isEmpty) return true;

    endDateStr = endDateStr.trim();
    try {
      DateTime? endDate;
      try {
        endDate = DateTime.parse(endDateStr);
      } catch (_) {
        try {
          endDate = DateFormat('dd/MM/yyyy').parse(endDateStr);
        } catch (_) {
           try {
             endDate = DateFormat('dd-MM-yyyy').parse(endDateStr);
           } catch (_) {}
        }
      }

      if (endDate == null) return true;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      
      // Nếu ngày kết thúc nhỏ hơn ngày hiện tại -> Đã kết thúc
      return !end.isBefore(today);
    } catch (e) {
      return true;
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final courses = await _courseService.getCourses();
      final current = <Map<String, dynamic>>[];
      final completed = <Map<String, dynamic>>[];

      for (final c in courses) {
        c['present'] = c['attendance_present'] ?? 0;
        c['total'] = c['attendance_total'] ?? 0;
        c['onTime'] = c['attendance_on_time'] ?? 0;
        c['absent'] = c['attendance_absent'] ?? 0;

        if (_isCourseActive(c)) {
          current.add(c);
        } else {
          completed.add(c);
        }
      }

      if (mounted) {
        setState(() {
          _currentCourses = current;
          _completedCourses = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      if (mounted) {
        setState(() {
          _currentCourses = [];
          _completedCourses = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getAvailableSemesters(List<Map<String, dynamic>> courses) {
    final Map<int, String> semesters = {};
    for (var course in courses) {
      if (course['semester'] is Map) {
        final id = course['semester']['id'];
        final name = course['semester']['name'];
        if (id != null && name != null) {
          semesters[id] = name;
        }
      }
    }
    return semesters.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    // Lọc khóa học đã học theo học kỳ
    final filteredCompletedCourses = _selectedSemesterId == null
        ? _completedCourses
        : _completedCourses.where((c) => c['semester'] is Map && c['semester']['id'] == _selectedSemesterId).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: [
                Tab(text: 'Đang học'),
                Tab(text: 'Đã học'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Đang học
                ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (_currentCourses.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.only(top: 20), child: Text('Không có khóa học nào đang học'))),
                    ..._currentCourses.map((course) {
                      return _AttendanceItem(
                        subject: course['subject'],
                        present: course['present'],
                        total: course['total'],
                        onTime: course['onTime'],
                        absent: course['absent'] ?? 0,
                        semester: course['semester'] is Map ? course['semester']['name'] : null,
                        endDate: course['endDate'],
                      );
                    }).toList(),
                  ],
                ),
                
                // Tab 2: Đã học (có filter)
                Column(
                  children: [
                    // Filter Bar
                    if (_completedCourses.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.grey[50],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Lọc theo học kỳ:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isDense: true,
                                  hint: const Text('Tất cả', style: TextStyle(fontSize: 13)),
                                  value: _selectedSemesterId,
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('Tất cả', style: TextStyle(fontSize: 13)),
                                    ),
                                    ..._getAvailableSemesters(_completedCourses).map((sem) {
                                      return DropdownMenuItem<int>(
                                        value: sem['id'],
                                        child: Text(sem['name'], style: const TextStyle(fontSize: 13)),
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
                        ),
                      ),
                    
                    // List
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          if (filteredCompletedCourses.isEmpty)
                            const Center(child: Padding(padding: EdgeInsets.only(top: 20), child: Text('Không có khóa học nào'))),
                          ...filteredCompletedCourses.map((course) {
                            return _AttendanceItem(
                              subject: course['subject'],
                              present: course['present'],
                              total: course['total'],
                              onTime: course['onTime'],
                              absent: course['absent'] ?? 0,
                              semester: course['semester'] is Map ? course['semester']['name'] : null,
                              endDate: course['endDate'],
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => _AttendanceDetailSheet(courseData: course),
                                );
                              },
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab 4: Hóa đơn (với fallback mẫu)

class BillingTab extends StatefulWidget {
  final User user;
  const BillingTab({super.key, required this.user});

  @override
  State<BillingTab> createState() => _BillingTabState();
}

class _BillingTabState extends State<BillingTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _currentBills = [];
  List<Map<String, dynamic>> _pastBills = [];

  @override
  void initState() {
    super.initState();
    _loadBilling();
  }

  Future<void> _loadBilling() async {
    try {
      final String response = await rootBundle.loadString('assets/data/billing.json');
      final data = await json.decode(response);
      setState(() {
        _currentBills = List<Map<String, dynamic>>.from(data['current_bills'] ?? []);
        _pastBills = List<Map<String, dynamic>>.from(data['completed_bills'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _currentBills = [
          {'title': 'Học phí Toán 9 - tháng 10', 'amount': '840.000 VND', 'date': '10/10/2025', 'isPaid': false},
          {'title': 'Học phí Anh 12 - tháng 10', 'amount': '1.980.000 VND', 'date': '12/10/2025', 'isPaid': false},
        ];
        _pastBills = [
          {'title': 'Học phí Toán 9 - tháng 9', 'amount': '840.000 VND', 'date': '10/09/2025', 'isPaid': true},
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_currentBills.isEmpty && _pastBills.isEmpty) return Center(child: Text('Không có hóa đơn nào.', style: TextStyle(color: Colors.grey[600])));

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text('HÓA ĐƠN HIỆN TẠI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 8),
        ..._currentBills.map((bill) {
          return _BillingItem(title: bill['title'] ?? 'Hóa đơn', amount: bill['amount']?.toString() ?? '0', date: bill['date'] ?? 'N/A', isPaid: bill['isPaid'] == true);
        }).toList(),
        const SizedBox(height: 24),
        Text('HÓA ĐƠN CŨ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 8),
        ..._pastBills.map((bill) {
          return _BillingItem(title: bill['title'] ?? 'Hóa đơn', amount: bill['amount']?.toString() ?? '0', date: bill['date'] ?? 'N/A', isPaid: bill['isPaid'] == true);
        }).toList(),
      ],
    );
  }
}

/// Tab 5: Phản hồi (với fallback mẫu)

class FeedbackTab extends StatefulWidget {
  final User user;
  const FeedbackTab({super.key, required this.user});

  @override
  State<FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<FeedbackTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _feedbacks = [];

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    try {
      final String response = await rootBundle.loadString('assets/data/feedback.json');
      final data = await json.decode(response);
      setState(() {
        _feedbacks = List<Map<String, dynamic>>.from(data['current_feedback'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _feedbacks = [
          {'course': 'Toán 9 - Lớp số 1', 'feedback': 'Giáo viên nhiệt tình, học sinh tiến bộ rõ rệt.', 'date': '15/10/2025'},
          {'course': 'Anh Văn 12 - Lớp số 1', 'feedback': 'Cần tăng bài tập về nhà để nâng cao kỹ năng.', 'date': '05/10/2025'},
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        ElevatedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chức năng gửi phản hồi đang được phát triển!'))),
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Gửi phản hồi mới'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
        const SizedBox(height: 24),
        if (_feedbacks.isEmpty)
          Center(child: Text('Chưa có phản hồi.', style: TextStyle(color: Colors.grey[600])))
        else
          ..._feedbacks.map((fb) => _FeedbackItem(course: fb['course'] ?? 'Khóa học', feedback: fb['feedback'] ?? '', date: fb['date'] ?? '')).toList(),
      ],
    );
  }
}

/// Tab 6: Cảnh báo (với fallback mẫu)

class WarningTab extends StatefulWidget {
  final User user;
  const WarningTab({super.key, required this.user});

  @override
  State<WarningTab> createState() => _WarningTabState();
}

class _WarningTabState extends State<WarningTab> {
  final StudentService _studentService = StudentService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _warnings = [];

  @override
  void initState() {
    super.initState();
    _loadWarnings();
  }

  Future<void> _loadWarnings() async {
    try {
      // Load warnings from notifications API
      final allNotifs = await _studentService.getNotifications();
      
      // Filter for WARNING and ATTENDANCE notifications for this student
      final warningNotifs = allNotifs.where((n) {
        final rid = n['receiverId'] ?? n['receiver_id'];
        bool isForMe = false;
        if (rid is int) isForMe = rid == widget.user.id;
        if (rid is String) isForMe = int.tryParse(rid) == widget.user.id;
        
        final notifType = (n['notificationType'] ?? n['notification_type'] ?? '').toString().toUpperCase();
        
        return isForMe && (notifType == 'WARNING' || notifType == 'ATTENDANCE');
      }).toList();
      
      // Convert to warning format
      final warnings = warningNotifs.map((n) {
        final sentAtRaw = n['sentAt'];
        String date = '';
        if (sentAtRaw != null) {
          try {
            final dt = DateTime.parse(sentAtRaw);
            date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
          } catch (_) {}
        }
        
        return {
          'title': n['title'] ?? 'Cảnh báo',
          'content': n['message'] ?? '',
          'date': date,
        };
      }).toList();
      
      setState(() {
        _warnings = warnings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _warnings = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_warnings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(
              'Không có cảnh báo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đang học tập rất tốt!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: _warnings.map((warning) {
        return _WarningItem(
          title: warning['title'] ?? 'Cảnh báo',
          content: warning['content'] ?? '',
          date: warning['date'] ?? '',
        );
      }).toList(),
    );
  }
}

// --- Các widget nhỏ có thể tái sử dụng (giữ nhất quán với file gốc) ---


class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)), const Divider(height: 24, thickness: 1), ...children])),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Colors.grey[600], size: 20), const SizedBox(width: 16), Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)), Expanded(child: Text(value, style: const TextStyle(fontSize: 15), textAlign: TextAlign.end))]));
  }
}

class _GradeItem extends StatelessWidget {
  final String subject;
  final String grade;
  final String? semester;
  final String? endDate;
  final VoidCallback? onTap;

  const _GradeItem({
    required this.subject,
    required this.grade,
    this.semester,
    this.endDate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPlaceholder = grade == 'N/A' || grade == '0.0' || grade == '0';
    
    String displayName = subject;
    if (semester != null && semester!.isNotEmpty) {
      displayName += ' - $semester';
    }

    // Convert date format from YYYY-MM-DD to DD-MM-YYYY
    String? formattedEndDate = endDate;
    if (endDate != null && endDate!.isNotEmpty) {
      final parts = endDate!.split('-');
      if (parts.length == 3) {
        formattedEndDate = '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPlaceholder ? Colors.blue.shade50 : null,
              child: isPlaceholder
                  ? const Icon(Icons.school, color: Colors.blue)
                  : Text(grade, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: formattedEndDate != null && formattedEndDate.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.event_busy, size: 14, color: Colors.red.shade400),
                        const SizedBox(width: 4),
                        Text('Kết thúc: $formattedEndDate', style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
                      ],
                    ),
                  )
                : null,
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class _GradeDetailSheet extends StatelessWidget {
  final Map<String, dynamic> courseData;

  const _GradeDetailSheet({required this.courseData});

  Widget _buildScoreRow(String label, dynamic score, {bool isBold = false}) {
    final String displayScore = score != null ? score.toString() : '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(displayScore, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          (courseData['subject'] ?? 'Khóa học') +
              (courseData['semester'] is Map && courseData['semester']['name'] != null
                  ? ' - ${courseData['semester']['name']}'
                  : ''),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildScoreRow('Cột 1', courseData['score_1']),
        const Divider(),
        _buildScoreRow('Cột 2', courseData['score_2']),
        const Divider(),
        _buildScoreRow('Cột 3', courseData['score_3']),
        const Divider(),
        _buildScoreRow('Điểm trung bình', courseData['final_score'], isBold: true),
        const Divider(),
        const Text('Nhận xét của giáo viên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Display all teacher comments
        ..._buildTeacherComments(courseData),
        const SizedBox(height: 20),
      ]),
    );
  }

  List<Widget> _buildTeacherComments(Map<String, dynamic> courseData) {
    final comments = courseData['teacherComments'];
    
    // If teacherComments is a list, display all
    if (comments is List && comments.isNotEmpty) {
      return comments.asMap().entries.map((entry) {
        final index = entry.key;
        final comment = entry.value.toString();
        return Padding(
          padding: EdgeInsets.only(bottom: index < comments.length - 1 ? 12.0 : 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.comment, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comment,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList();
    }
    
    // Fallback to old single comment for backward compatibility
    final singleComment = courseData['teacherComment'];
    if (singleComment != null && singleComment.toString().isNotEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '"$singleComment"',
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.black87,
            ),
          ),
        ),
      ];
    }
    
    // No comments
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Chưa có nhận xét',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      ),
    ];
  }
}

class _AttendanceItem extends StatelessWidget {
  final String subject;
  final int present;
  final int total;
  final int onTime;
  final int absent;
  final String? semester;
  final String? endDate;
  final VoidCallback? onTap;

  const _AttendanceItem({
    required this.subject,
    required this.present,
    required this.total,
    required this.onTime,
    this.absent = 0,
    this.semester,
    this.endDate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    double percentage = total > 0 ? present / total : 0;
    
    String displayName = subject;
    if (semester != null && semester!.isNotEmpty) {
      displayName += ' - $semester';
    }

    // Convert date format from YYYY-MM-DD to DD-MM-YYYY
    String? formattedEndDate = endDate;
    if (endDate != null && endDate!.isNotEmpty) {
      final parts = endDate!.split('-');
      if (parts.length == 3) {
        formattedEndDate = '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (formattedEndDate != null && formattedEndDate.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.event_busy, size: 14, color: Colors.red.shade400),
                      const SizedBox(width: 4),
                      Text('Kết thúc: $formattedEndDate', style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text('Số buổi có mặt: $present/$total'),
              Text('Số buổi đúng giờ: $onTime/$present'),
              Text('Số buổi vắng: $absent'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[300],
                color: percentage > 0.8 ? Colors.green : Colors.orange,
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceDetailSheet extends StatelessWidget {
  final Map<String, dynamic> courseData;

  const _AttendanceDetailSheet({required this.courseData});

  @override
  Widget build(BuildContext context) {
    final attendances = (courseData['attendances'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    // Sort by date descending
    attendances.sort((a, b) {
      final dateA = a['attendanceDate'] ?? '';
      final dateB = b['attendanceDate'] ?? '';
      return dateB.compareTo(dateA);
    });
    
    final courseName = courseData['subject'] ?? 'Khóa học';
    final semester = courseData['semester'] is Map ? courseData['semester']['name'] : '';
    
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
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        courseName + (semester.isNotEmpty ? ' - $semester' : ''),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tổng số: ${attendances.length} buổi',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          
          // Attendance List
          Expanded(
            child: attendances.isEmpty
                ? const Center(child: Text('Chưa có dữ liệu điểm danh'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: attendances.length,
                    itemBuilder: (context, index) {
                      final item = attendances[index];
                      var date = item['attendanceDate'] ?? item['attendance_date'] ?? item['date'] ?? 'N/A';
                      
                      // Convert date format to DD-MM-YYYY
                      if (date != null && date.toString().isNotEmpty && date != 'N/A') {
                        final dateStr = date.toString().trim();
                        // Handle YYYY-MM-DD format
                        if (dateStr.contains('-')) {
                          final parts = dateStr.split('-');
                          if (parts.length == 3 && parts[0].length == 4) {
                            // YYYY-MM-DD -> DD-MM-YYYY
                            date = '${parts[2]}-${parts[1]}-${parts[0]}';
                          }
                        }
                        // Handle DD/MM/YYYY format
                        else if (dateStr.contains('/')) {
                          final parts = dateStr.split('/');
                          if (parts.length == 3) {
                            // Convert / to -
                            date = '${parts[0]}-${parts[1]}-${parts[2]}';
                          }
                        }
                      }
                      
                      final rawStatus = (item['status'] ?? 'UNKNOWN').toString().toUpperCase();
                      final reason = item['permissionReason'];
                      
                      final isPresent = rawStatus == 'PRESENT' || rawStatus == 'CÓ MẶT';
                      final isAbsent = rawStatus == 'ABSENT' || rawStatus == 'VẮNG' || rawStatus == 'VẮNG MẶT';
                      final isLate = rawStatus == 'LATE' || rawStatus == 'MUỘN';
                      
                      String displayStatus = 'Vắng mặt';
                      Color statusColor = Colors.red;
                      IconData statusIcon = Icons.close_rounded;

                      if (isPresent) {
                        displayStatus = 'Có mặt';
                        statusColor = Colors.green;
                        statusIcon = Icons.check_rounded;
                      } else if (isLate) {
                        displayStatus = 'Đi muộn';
                        statusColor = Colors.orange;
                        statusIcon = Icons.access_time_rounded;
                      }
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border(
                            left: BorderSide(
                              color: statusColor,
                              width: 4,
                            ),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              statusIcon,
                              color: statusColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Ngày: $date',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                displayStatus,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (!isPresent && reason != null && reason.toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Lý do: $reason',
                                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BillingItem extends StatelessWidget {
  final String title;
  final String amount;
  final String date;
  final bool isPaid;

  const _BillingItem({required this.title, required this.amount, required this.date, required this.isPaid});

  @override
  Widget build(BuildContext context) {
    return Card(child: ListTile(title: Text(title), subtitle: Text('Số tiền: $amount - Hạn chót: $date'), trailing: Chip(label: Text(isPaid ? 'Đã thanh toán' : 'Chưa thanh toán'), backgroundColor: isPaid ? Colors.green.shade100 : Colors.red.shade100, labelStyle: TextStyle(color: isPaid ? Colors.green.shade800 : Colors.red.shade800))));
  }
}

class _FeedbackItem extends StatelessWidget {
  final String course;
  final String feedback;
  final String date;

  const _FeedbackItem({required this.course, required this.feedback, required this.date});

  @override
  Widget build(BuildContext context) {
    return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(title: Text('Phản hồi về: $course'), subtitle: Text('"$feedback"\n- Ngày: $date'), isThreeLine: true));
  }
}

class _WarningItem extends StatelessWidget {
  final String title;
  final String content;
  final String date;

  const _WarningItem({required this.title, required this.content, required this.date});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.red.shade50,
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900),
        ),
        subtitle: Text(
          '$content\n- Ngày: $date',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Icon(Icons.chevron_right, color: Colors.red.shade700),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _WarningDetailSheet(
              title: title,
              content: content,
              date: date,
            ),
          );
        },
      ),
    );
  }
}

/// Bottom sheet hiển thị chi tiết cảnh báo
class _WarningDetailSheet extends StatelessWidget {
  final String title;
  final String content;
  final String date;

  const _WarningDetailSheet({
    required this.title,
    required this.content,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
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
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiết cảnh báo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CẢNH BÁO',
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
                  
                  // Date
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Ngày: $date',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  
                  // Full content
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
                    content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Warning notice
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
                        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vui lòng liên hệ giáo viên hoặc phụ huynh để được hỗ trợ.',
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
                  backgroundColor: Colors.red,
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