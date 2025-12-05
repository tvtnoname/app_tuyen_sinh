import 'package:flutter/material.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/auth/SplashScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/auth/LoginScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/student/StudentHomeScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/parent/ParentHomeScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/teacher/TeacherHomeScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/models/user.dart';

/// Điểm khởi chạy chính của ứng dụng.
/// Hàm này thiết lập và khởi chạy widget gốc [MyApp].
void main() {
  runApp(const MyApp());
}

/// Widget gốc của toàn bộ ứng dụng.
/// Chịu trách nhiệm cấu hình giao diện (theme) và quản lý điều hướng (routing).
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Tạo một trang lỗi mặc định khi điều hướng thất bại hoặc không tìm thấy route.
  Route<dynamic> _errorRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Lỗi trang')),
        body: Center(child: Text('Không tìm thấy route: ${settings.name}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Quản lý tuyển sinh',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Times New Roman',
      ),
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/studentHome':
            final args = settings.arguments;
            if (args is User) {
              return MaterialPageRoute(builder: (_) => StudentHomeScreen(user: args));
            } else if (args is Map<String, dynamic>) {
              final user = User.fromJson(args);
              return MaterialPageRoute(builder: (_) => StudentHomeScreen(user: user));
            } else {
              return _errorRoute(settings);
            }
          case '/parentHome':
            final args = settings.arguments;
            if (args is User) {
              return MaterialPageRoute(builder: (_) => ParentHomeScreen(user: args));
            } else if (args is Map<String, dynamic>) {
              final user = User.fromJson(args);
              return MaterialPageRoute(builder: (_) => ParentHomeScreen(user: user));
            } else {
              return _errorRoute(settings);
            }
          case '/teacherHome':
            final args = settings.arguments;
            if (args is User) {
              return MaterialPageRoute(builder: (_) => TeacherHomeScreen(user: args));
            } else if (args is Map<String, dynamic>) {
              final user = User.fromJson(args);
              return MaterialPageRoute(builder: (_) => TeacherHomeScreen(user: user));
            } else {
              return _errorRoute(settings);
            }
          default:
            return _errorRoute(settings);
        }
      },
      debugShowCheckedModeBanner: false,
    );
  }
}