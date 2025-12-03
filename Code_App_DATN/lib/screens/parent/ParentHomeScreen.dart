import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../ParentHomeWidget/ParentHomeTab.dart';
import '../../ParentHomeWidget/ParentScheduleTab.dart';
import '../../ParentHomeWidget/ParentResultsTab.dart';
import '../../ParentHomeWidget/ParentPaymentTab.dart';
import '../../ParentHomeWidget/ParentProfileTab.dart';

class ParentHomeScreen extends StatefulWidget {
  final User user;
  const ParentHomeScreen({super.key, required this.user});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _selectedIndex = 0;
  DateTime? _lastTapTime;
  
  // GlobalKey để truy cập trạng thái của từng tab
  final GlobalKey<ParentHomeTabState> _homeKey = GlobalKey<ParentHomeTabState>();
  final GlobalKey<ParentScheduleTabState> _scheduleKey = GlobalKey<ParentScheduleTabState>();
  final GlobalKey<ParentResultsTabState> _resultsKey = GlobalKey<ParentResultsTabState>();
  final GlobalKey<ParentPaymentTabState> _paymentKey = GlobalKey<ParentPaymentTabState>();
  final GlobalKey<ParentProfileTabState> _profileKey = GlobalKey<ParentProfileTabState>();
  
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ParentHomeTab(key: _homeKey, user: widget.user),
      ParentScheduleTab(key: _scheduleKey),
      ParentResultsTab(key: _resultsKey),
      ParentPaymentTab(key: _paymentKey),
      ParentProfileTab(
        key: _profileKey, 
        user: widget.user,
        onProfileUpdated: () {
          _homeKey.currentState?.reload();
        },
      ),
    ];
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      // Phát hiện double tap
      final now = DateTime.now();
      if (_lastTapTime != null && now.difference(_lastTapTime!) < const Duration(milliseconds: 500)) {
        _handleDoubleTap(index);
      }
      _lastTapTime = now;
    } else {
      setState(() {
        _selectedIndex = index;
      });
      _lastTapTime = null;
    }
  }

  void _handleDoubleTap(int index) {
    switch (index) {
      case 0: // Tab Trang chủ
        _homeKey.currentState?.reload();
        break;
      case 1: // Tab Lịch học
        _scheduleKey.currentState?.reload();
        break;
      case 2: // Tab Kết quả
        _resultsKey.currentState?.reload();
        break;
      case 3: // Tab Thanh toán
        _paymentKey.currentState?.reload();
        break;
      case 4: // Tab Hồ sơ
        _profileKey.currentState?.reload();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Lịch học'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Kết quả'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Thanh toán'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Hồ sơ'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueGrey,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

