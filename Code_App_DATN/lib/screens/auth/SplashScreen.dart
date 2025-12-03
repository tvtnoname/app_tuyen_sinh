import 'package:flutter/material.dart';
import '../../services/auth/auth_service.dart';
import '../../models/user.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Thêm độ trễ nhỏ để tạo hiệu ứng hình ảnh hoặc đảm bảo async prefs đã sẵn sàng
    await Future.delayed(const Duration(seconds: 1));

    try {
      final token = await _authService.getToken();
      if (token != null && token.isNotEmpty) {
        // Token tồn tại, thử lấy thông tin hồ sơ/vai trò
        final User? user = await _authService.fetchProfile();
        
        if (user != null && user.role != null) {
          final role = user.role!.replaceAll('ROLE_', '').toUpperCase();
          if (mounted) {
            _navigateBasedOnRole(role, user);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Auto-login failed: $e');
    }

    // Nếu token không hợp lệ hoặc lấy thông tin thất bại, chuyển đến trang Đăng nhập
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  /// Điều hướng người dùng dựa trên vai trò (Role).
  void _navigateBasedOnRole(String role, User user) {
    String routeName;
    switch (role) {
      case 'STUDENT':
        routeName = '/studentHome';
        break;
      case 'PARENT':
        routeName = '/parentHome';
        break;
      case 'TEACHER':
        routeName = '/teacherHome';
        break;
      default:
        routeName = '/login';
    }
    Navigator.of(context).pushReplacementNamed(routeName, arguments: user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}