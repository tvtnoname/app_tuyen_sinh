import 'package:app_quan_ly_tuyen_sinh/services/teacher/teacher_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final Map<String, dynamic> classData;

  const StudentDetailScreen({
    super.key,
    required this.studentData,
    required this.classData,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final TeacherService _teacherService = TeacherService();
  late Map<String, dynamic> _studentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _studentData = widget.studentData;
    _loadStudentDetail();
  }

  /// Helper to format date
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Chưa cập nhật';
    try {
      // Handle potential existing formats
      DateTime? date;
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        try {
          date = DateFormat('dd-MM-yyyy').parse(dateStr);
        } catch (_) {}
      }
      
      if (date != null) {
        return DateFormat('dd-MM-yyyy').format(date);
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  /// Tải thông tin chi tiết của học viên từ API.
  Future<void> _loadStudentDetail() async {
    try {
      final studentId = widget.studentData['studentId'] ?? widget.studentData['userId'] ?? widget.studentData['id'];
      debugPrint('StudentDetailScreen: Loading detail for studentId: $studentId');
      
      if (studentId != null) {
        final detail = await _teacherService.getStudentDetail(studentId);
        debugPrint('StudentDetailScreen: Received detail: $detail');
        
        if (detail != null && mounted) {
          setState(() {
            _studentData = {..._studentData, ...detail};
            _isLoading = false;
          });
        } else {
          debugPrint('StudentDetailScreen: Detail is null');
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        debugPrint('StudentDetailScreen: studentId is null');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading student detail: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = _studentData['fullName'] ?? _studentData['name'] ?? 'Học viên';
    final studentId = _studentData['studentId'] ?? _studentData['userId'] ?? _studentData['id'];
    final className = widget.classData['name'] ?? widget.classData['className'] ?? 'Lớp học';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ học viên'),
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thẻ thông tin học viên
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              studentName.isNotEmpty ? studentName.substring(0, 1).toUpperCase() : '?',
                              style: const TextStyle(fontSize: 24, color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mã học viên: ${_studentData['studentCode'] ?? _studentData['code'] ?? 'N/A'}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                Text(
                                  'ID: $studentId',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Phần thông tin cá nhân
                  const Text(
                    'Thông tin cá nhân',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildInfoRow('Ngày sinh', _formatDate(_studentData['dob'] ?? _studentData['user']?['dob'] ?? _studentData['dateOfBirth'])),
                          const Divider(height: 16),
                          _buildInfoRow('Giới tính', _studentData['gender'] ?? _studentData['user']?['gender'] ?? 'Chưa cập nhật'),
                          const Divider(height: 16),
                          _buildInfoRow('Email', _studentData['email'] ?? _studentData['user']?['email'] ?? 'Chưa cập nhật'),
                          const Divider(height: 16),
                          _buildInfoRow('Số điện thoại', _studentData['phone'] ?? _studentData['user']?['phone'] ?? _studentData['phoneNumber'] ?? 'Chưa cập nhật'),
                          const Divider(height: 16),
                          _buildInfoRow('Địa chỉ', _studentData['address'] ?? _studentData['user']?['address'] ?? 'Chưa cập nhật'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Phần bảng điểm
                  const Text(
                    'Bảng điểm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lớp: $className',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        _buildGradeRow('Cột 1', _studentData['score1'] ?? _studentData['score_1']),
                        const Divider(height: 1),
                        _buildGradeRow('Cột 2', _studentData['score2'] ?? _studentData['score_2']),
                        const Divider(height: 1),
                        _buildGradeRow('Cột 3', _studentData['score3'] ?? _studentData['score_3']),
                        const Divider(height: 1),
                        _buildGradeRow('Điểm trung bình', _studentData['finalScore'] ?? _studentData['final_score'], isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Nút nhận xét
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCommentDialog(context),
                      icon: const Icon(Icons.comment),
                      label: const Text('Nhận xét'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  /// Widget hiển thị một hàng điểm số.
  Widget _buildGradeRow(String label, dynamic score, {bool isBold = false}) {
    String displayScore = 'Chưa có';
    Color textColor = Colors.grey;

    if (score != null) {
      displayScore = score.toString();
      textColor = isBold ? Colors.blue : Colors.black87;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            displayScore,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị một dòng thông tin cá nhân.
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  /// Hiển thị hộp thoại gửi nhận xét.
  void _showCommentDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CommentDialog(
        studentData: widget.studentData,
        classData: widget.classData,
        teacherService: _teacherService,
      ),
    );
  }
}

class _CommentDialog extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final Map<String, dynamic> classData;
  final TeacherService teacherService;

  const _CommentDialog({
    required this.studentData,
    required this.classData,
    required this.teacherService,
  });

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Gửi nhận xét lên server.
  Future<void> _sendComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung nhận xét')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final studentId = widget.studentData['studentId'] ?? widget.studentData['userId'] ?? widget.studentData['id'];
      final classId = widget.classData['classId'] ?? widget.classData['id'];

      if (studentId == null || classId == null) {
        throw Exception('Thiếu thông tin học viên hoặc lớp học');
      }

      await widget.teacherService.sendStudentNotification(
        studentId: studentId,
        classId: classId,
        title: 'Nhận xét từ giáo viên',
        message: comment,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi nhận xét thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi nhận xét: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nhận xét học viên'),
      content: SingleChildScrollView(
        child: TextField(
          controller: _commentController,
          maxLines: 5,
          enabled: !_isSending,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập nhận xét của giáo viên...',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendComment,
          child: _isSending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Gửi'),
        ),
      ],
    );
  }
}
