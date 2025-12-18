import '../../StudentHomeWidget/Home.dart';
import '../../StudentHomeWidget/Profile.dart';
import '../../StudentHomeWidget/Schedule.dart';
import '../../services/auth/auth_service.dart';
import '../common/ChatScreen.dart'; // Import ChatScreen
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
      child: DraggableChatButton(
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
      ),
    );
  }
}

class DraggableChatButton extends StatefulWidget {
  final Widget child;
  const DraggableChatButton({super.key, required this.child});

  @override
  State<DraggableChatButton> createState() => _DraggableChatButtonState();
}

class _DraggableChatButtonState extends State<DraggableChatButton> {
  Offset _fabOffset = Offset.zero;
  bool _isFabInit = false;

  @override
  Widget build(BuildContext context) {
    if (!_isFabInit) {
      final size = MediaQuery.of(context).size;
      _fabOffset = Offset(size.width - 80, size.height - 160);
      _isFabInit = true;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: _fabOffset.dx,
          top: _fabOffset.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final size = MediaQuery.of(context).size;
                double dx = _fabOffset.dx + details.delta.dx;
                double dy = _fabOffset.dy + details.delta.dy;
                // Adjust clamp for larger size and text
                dx = dx.clamp(0.0, size.width - 80);
                dy = dy.clamp(0.0, size.height - 120);
                _fabOffset = Offset(dx, dy);
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hỗ trợ 24/7',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChatScreen()),
                      );
                    },
                    child: Container(
                      width: 70, // Restored to 70
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3F2FD),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.support_agent_rounded, size: 40, color: Color(0xFF1976D2)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}