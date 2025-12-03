import '../../TeacherHomeWidget/TeacherHome.dart';
import '../../TeacherHomeWidget/TeacherClasses.dart';
import '../../TeacherHomeWidget/TeacherSchedule.dart';
import '../../TeacherHomeWidget/TeacherProfile.dart';
import 'package:app_quan_ly_tuyen_sinh/services/teacher/teacher_service.dart';
import 'package:flutter/material.dart';
import '../../models/user.dart';

class TeacherHomeScreen extends StatefulWidget {
  final User user;
  const TeacherHomeScreen({super.key, required this.user});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _selectedIndex = 0;
  late User _currentUser;
  final TeacherService _teacherService = TeacherService();

  // GlobalKey để truy cập trạng thái của từng tab
  final GlobalKey<TeacherHomeState> _homeKey = GlobalKey<TeacherHomeState>();
  final GlobalKey<TeacherClassesState> _classesKey = GlobalKey<TeacherClassesState>();
  final GlobalKey<TeacherScheduleState> _scheduleKey = GlobalKey<TeacherScheduleState>();
  final GlobalKey<TeacherProfileState> _profileKey = GlobalKey<TeacherProfileState>();

  // Theo dõi thời gian chạm cuối cùng để phát hiện double-tap
  DateTime _lastTapTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  void _onItemTapped(int index) {
    final now = DateTime.now();
    // Kiểm tra nếu chạm 2 lần vào cùng một tab trong vòng 300ms
    if (_selectedIndex == index && now.difference(_lastTapTime) < const Duration(milliseconds: 300)) {
      _handleDoubleClick(index);
    }
    
    _lastTapTime = now;

    setState(() {
      _selectedIndex = index;
    });
  }

  /// Xử lý sự kiện double-click để tải lại dữ liệu của tab.
  void _handleDoubleClick(int index) {
    switch (index) {
      case 0:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải lại Trang chủ...')));
        _homeKey.currentState?.reload();
        break;
      case 1:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải lại Lớp học...')));
        _classesKey.currentState?.reload();
        break;
      case 2:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải lại Lịch dạy...')));
        _scheduleKey.currentState?.reload();
        break;
      case 3:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải lại Hồ sơ...')));
        _profileKey.currentState?.reload();
        break;
    }
  }

  /// Hàm hỗ trợ chuyển đổi chuỗi giới tính sang enum Gender.
  Gender _parseGender(String? genderStr) {
    if (genderStr == null) return Gender.unknown;
    final upper = genderStr.toUpperCase();
    if (upper.contains('MALE') && !upper.contains('FEMALE')) return Gender.male;
    if (upper.contains('FEMALE')) return Gender.female;
    return Gender.unknown;
  }

  /// Tải lại dữ liệu người dùng từ server và cập nhật tất cả các tab.
  Future<void> _reloadUserData() async {
    try {
      final profileData = await _teacherService.getTeacherProfile();
      if (profileData != null && profileData['user'] != null) {
        final userData = profileData['user'];
        
        // Cập nhật người dùng hiện tại với dữ liệu mới
        setState(() {
          _currentUser = User(
            id: _currentUser.id,
            userName: userData['userName'] ?? _currentUser.userName,
            fullName: userData['fullName'] ?? _currentUser.fullName,
            email: userData['email'] ?? _currentUser.email,
            phone: userData['phone'] ?? _currentUser.phone,
            address: userData['address'] ?? _currentUser.address,
            dob: userData['dob'] != null ? DateTime.tryParse(userData['dob'].toString()) : _currentUser.dob,
            gender: userData['gender'] != null ? _parseGender(userData['gender'].toString()) : _currentUser.gender,
            role: _currentUser.role,
          );
        });

        // Tải lại tab Trang chủ để cập nhật avatar và thông tin
        _homeKey.currentState?.reload();
      }
    } catch (e) {
      debugPrint('Error reloading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false; // Không thoát ứng dụng
        }
        return true; // Thoát ứng dụng (hoặc thu nhỏ)
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            TeacherHome(key: _homeKey, user: _currentUser),
            TeacherClasses(key: _classesKey),
            TeacherSchedule(key: _scheduleKey),
            TeacherProfile(
              key: _profileKey, 
              user: _currentUser,
              onProfileUpdated: _reloadUserData,
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.class_),
              label: 'Lớp học',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Lịch dạy',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Hồ sơ',
            ),
          ],
        ),
      ),
    );
  }
}
