import '../../StudentHomeWidget/Home.dart';
import '../../StudentHomeWidget/Profile.dart';
import '../../StudentHomeWidget/Schedule.dart';
import '../../services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import '../../models/user.dart';

class StudentHomeScreen extends StatefulWidget {
  final User user;

  const StudentHomeScreen({super.key, required this.user});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHomeScreen> {
  int _selectedIndex = 0;
  late User _currentUser;
  final AuthService _authService = AuthService();

  // GlobalKey để truy cập trạng thái của từng màn hình con
  final GlobalKey<ScheduleState> _scheduleScreenKey = GlobalKey<ScheduleState>();
  final GlobalKey<HomeState> _homeKey = GlobalKey<HomeState>();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey<ProfileScreenState>();

  // Thời điểm nhấn cuối cùng để xử lý double-tap
  DateTime _lastTapTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  /// Tải lại dữ liệu người dùng từ server.
  Future<void> _reloadUserData() async {
    final newUser = await _authService.fetchProfile();
    if (newUser != null) {
      setState(() {
        _currentUser = newUser;
      });
      // Tải lại Home để cập nhật dữ liệu hiển thị
      _homeKey.currentState?.reload();
    }
  }

  void _onItemTapped(int index) {
    final now = DateTime.now();
    // Kiểm tra double-tap trong khoảng 300ms
    if (_selectedIndex == index && now.difference(_lastTapTime) < const Duration(milliseconds: 300)) {
      _handleDoubleClick(index);
    }
    
    _lastTapTime = now;

    setState(() {
      _selectedIndex = index;
    });
  }

  /// Xử lý sự kiện double-tap để tải lại tab tương ứng.
  void _handleDoubleClick(int index) {
    switch (index) {
      case 0:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải lại Trang chủ...')));
        _homeKey.currentState?.reload();
        break;
      case 1:
        // Tải lại lịch học
        _scheduleScreenKey.currentState?.reload();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải lại Lịch học...')));
        break;
      case 2:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải lại Thông tin...')));
        _profileKey.currentState?.reload();
        break;
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
        body: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              Home(key: _homeKey, user: _currentUser),
              Schedule(key: _scheduleScreenKey, user: _currentUser),
              Profile(key: _profileKey, user: _currentUser, onProfileUpdated: _reloadUserData),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Lịch học'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Thông tin'),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.amber[800],
        ),
      ),
    );
  }
}