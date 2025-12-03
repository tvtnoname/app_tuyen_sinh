import 'dart:convert';
import '../../services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import '../../models/user.dart';

/// Screen for user authentication.
/// Handles login logic and navigation based on user role.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Displays a snackbar with the given message.
  void _showSnack(String message, {Color? bgColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
      ),
    );
  }

  /// Decodes JWT payload to extract role and common claims.
  /// Used as a fallback when the profile API fails.
  User _enrichUserFromToken(User user) {
    final token = user.token;
    if (token == null || token.isEmpty) return user;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return user;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> claims = jsonDecode(decoded);

      // Extract a single role (try several claim names)
      String? role;
      if (claims['role'] != null) {
        role = claims['role'].toString();
      } else if (claims['roles'] != null) {
        final r = claims['roles'];
        if (r is List && r.isNotEmpty) role = r.first.toString();
        else if (r is String) role = r.split(',').first.trim();
      } else if (claims['authorities'] != null) {
        final a = claims['authorities'];
        if (a is List && a.isNotEmpty) role = a.first.toString();
        else if (a is String) role = a.split(',').first.trim();
      }

      if (role != null) role = role.replaceAll('ROLE_', '').toUpperCase();

      final fullName = claims['fullName'] ?? claims['name'] ?? claims['displayName'] ?? claims['sub'];
      final email = claims['email'] ?? claims['mail'];
      final phone = claims['phone'] ?? claims['mobile'];

      return user.copyWith(
        role: user.role ?? (role),
        fullName: user.fullName ?? (fullName?.toString()),
        email: user.email ?? (email?.toString()),
        phone: user.phone ?? (phone?.toString()),
      );
    } catch (_) {
      return user;
    }
  }

  /// Handles the login process.
  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showSnack('Vui lòng nhập tên đăng nhập và mật khẩu', bgColor: Colors.redAccent);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1) login (may return only token or partial user)
      User user = await _authService.login(username, password);

      // 2) try fetch full profile from server (now generic fetch that handles student/parent/teacher)
      try {
        final profile = await _authService.fetchProfile(username: user.userName);
        if (profile != null) {
          // prefer server profile (but preserve token)
          user = profile.copyWith(token: user.token ?? profile.token);
        } else {
          // fallback: try enrich from token if profile missing
          if (user.role == null || user.role!.isEmpty) {
            user = _enrichUserFromToken(user);
          }
        }
      } on Exception catch (e) {
        // if unauthorized -> force logout and prompt re-login
        if (e.toString().contains('Unauthorized')) {
          await _authService.logout();
          _showSnack('Phiên đã hết hạn. Vui lòng đăng nhập lại.', bgColor: Colors.redAccent);
          return;
        } else {
          debugPrint('fetchProfile failed: $e');
          // fallback: enrich from token
          if (user.role == null || user.role!.isEmpty) {
            user = _enrichUserFromToken(user);
          }
        }
      }

      // If still no role, show friendly error
      if (user.role == null || user.role!.isEmpty) {
        _showSnack('Không xác định vai trò người dùng. Vui lòng liên hệ quản trị hệ thống.', bgColor: Colors.redAccent);
        return;
      }

      final primaryRole = user.role!.replaceAll('ROLE_', '').toUpperCase();
      debugPrint('Login successful. User: ${user.userName}, Role: $primaryRole');

      String routeName;
      switch (primaryRole) {
        case 'STUDENT':
          routeName = '/studentHome';
          break;
        case 'PARENT':
          debugPrint('Navigating to Parent Home for user: ${user.userName}');
          routeName = '/parentHome';
          break;
        case 'TEACHER':
          routeName = '/teacherHome';
          break;
        default:
          _showSnack('Vai trò người dùng không được hỗ trợ: $primaryRole', bgColor: Colors.redAccent);
          return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(routeName, arguments: user);
    } catch (e) {
      final raw = e.toString();
      final message = raw.replaceAll('Exception: ', '');
      _showSnack(message, bgColor: Colors.redAccent);

      _passwordController.clear();
      _passwordFocus.requestFocus();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSubmittedPassword(String _) => _handleLogin();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.school_outlined, size: 80, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Chào mừng trở lại',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng nhập vào tài khoản của bạn',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  _buildTextField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    labelText: 'Tên đăng nhập',
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    labelText: 'Mật khẩu',
                    prefixIcon: Icons.lock_outline,
                    obscureText: !_isPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: _onSubmittedPassword,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    )
                        : const Text('Đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    FocusNode? focusNode,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon, color: Colors.grey[600]),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
    );
  }
}