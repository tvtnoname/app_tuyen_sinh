import 'package:app_quan_ly_tuyen_sinh/screens/teacher/AttendanceHistoryScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/teacher/AttendanceScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/teacher/GradeEntryScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/screens/student/StudentDetailScreen.dart';
import 'package:app_quan_ly_tuyen_sinh/services/teacher/teacher_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> classData;

  const ClassDetailScreen({super.key, required this.classData});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> with SingleTickerProviderStateMixin {
  final TeacherService _teacherService = TeacherService();
  late TabController _tabController;
  
  bool _isLoadingStudents = true;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Tải danh sách học viên của lớp học.
  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    
    try {
      final classId = widget.classData['classId'] ?? widget.classData['id'];
      if (classId != null) {
        final students = await _teacherService.getClassStudents(classId);
        
        // Sắp xếp học viên theo tên (A-Z)
        students.sort((a, b) {
          final nameA = (a['fullName'] ?? a['name'] ?? '').toString().trim();
          final nameB = (b['fullName'] ?? b['name'] ?? '').toString().trim();
          
          final firstNameA = nameA.split(' ').last;
          final firstNameB = nameB.split(' ').last;
          
          return firstNameA.compareTo(firstNameB);
        });
        
        if (mounted) {
          setState(() {
            _students = students;
            _isLoadingStudents = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading students: $e');
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final className = widget.classData['name'] ?? widget.classData['className'] ?? 'Lớp học';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(className),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Học viên'),
            Tab(text: 'Điểm danh'),
            Tab(text: 'Bảng điểm'),
            Tab(text: 'Thông tin'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentsTab(),
          _buildAttendanceTab(),
          _buildGradesTab(),
          _buildInfoTab(),
        ],
      ),
    );
  }

  /// Widget hiển thị tab danh sách học viên.
  Widget _buildStudentsTab() {
    if (_isLoadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có học viên nào',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _students.length + 1,
      itemBuilder: (context, index) {
        if (index == _students.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Center(
              child: Text(
                'Tổng số học viên: ${_students.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
          );
        }
        return _buildStudentCard(_students[index]);
      },
    );
  }

  /// Widget hiển thị thẻ thông tin tóm tắt của một học viên.
  Widget _buildStudentCard(Map<String, dynamic> student) {
    final studentName = student['fullName'] ?? student['name'] ?? 'Học viên';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            studentName.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
        // Đã ẩn email và số điện thoại theo yêu cầu
        subtitle: null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            switch (value) {
              case 'view':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentDetailScreen(
                      studentData: student,
                      classData: widget.classData,
                    ),
                  ),
                );
                break;
              case 'grade':
                _showGradeUpdateDialog(context, student);
                break;
              case 'notify':
                _showParentNotificationDialog(context, student);
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(value: 'view', child: Text('Xem hồ sơ')),
            const PopupMenuItem(value: 'grade', child: Text('Cập nhật điểm')),
            const PopupMenuItem(value: 'notify', child: Text('Thông báo phụ huynh')),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị tab điểm danh.
  Widget _buildAttendanceTab() {
    if (_isLoadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có học viên',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.green[400]),
          const SizedBox(height: 16),
          const Text(
            'Điểm danh lớp học',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${_students.length} học viên',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceScreen(
                    classData: widget.classData,
                    students: _students,
                  ),
                ),
              );
              
              // Hiển thị thông báo xác nhận nếu đã điểm danh
              if (result == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Điểm danh đã được lưu')),
                );
              }
            },
            icon: const Icon(Icons.checklist),
            label: const Text('Điểm danh ngay'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị tab bảng điểm.
  Widget _buildGradesTab() {
    if (_isLoadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grade_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có học viên',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note, size: 80, color: Colors.blue[400]),
          const SizedBox(height: 16),
          const Text(
            'Nhập điểm cho lớp học',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${_students.length} học viên',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GradeEntryScreen(
                    classData: widget.classData,
                    students: _students,
                  ),
                ),
              );
              
              // Tải lại nếu điểm số đã được cập nhật
              if (result == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Điểm đã được cập nhật')),
                );
              }
            },
            icon: const Icon(Icons.edit),
            label: const Text('Nhập điểm'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị tab thông tin chi tiết lớp học.
  Widget _buildInfoTab() {
    String subjectName = '';
    String gradeName = '';
    
    try {
      if (widget.classData['subject'] is Map) {
        subjectName = widget.classData['subject']['name'] ?? '';
      }
      if (widget.classData['grade'] is Map) {
        gradeName = widget.classData['grade']['name'] ?? '';
      }
    } catch (_) {}

    final studentCount = !_isLoadingStudents 
        ? _students.length 
        : (widget.classData['studentCount'] ?? widget.classData['currentStudents'] ?? 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin lớp học',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Tên lớp', widget.classData['name'] ?? 'N/A'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Môn học', subjectName.isEmpty ? 'N/A' : subjectName),
                  const SizedBox(height: 12),
                  _buildInfoRow('Khối', gradeName.isEmpty ? 'N/A' : gradeName),
                  const SizedBox(height: 12),
                  _buildInfoRow('Số học viên', studentCount.toString()),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AttendanceHistoryScreen(
                              classData: widget.classData,
                              students: _students,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('Danh sách điểm danh'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị một dòng thông tin (nhãn - giá trị).
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

  /// Hiển thị hộp thoại cập nhật điểm nhanh.
  void _showGradeUpdateDialog(BuildContext context, Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => _GradeUpdateDialog(
        student: student,
        classData: widget.classData,
        teacherService: _teacherService,
      ),
    ).then((updated) {
      if (updated == true) {
        // Làm mới danh sách học viên hoặc điểm số nếu cần
        // Hiện tại chỉ cần tải lại danh sách
        _loadStudents();
      }
    });
  }

  /// Hiển thị hộp thoại gửi thông báo đến phụ huynh.
  void _showParentNotificationDialog(BuildContext context, Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => _ParentNotificationDialog(
        student: student,
        classData: widget.classData,
        teacherService: _teacherService,
      ),
    );
  }
}

class _ParentNotificationDialog extends StatefulWidget {
  final Map<String, dynamic> student;
  final Map<String, dynamic> classData;
  final TeacherService teacherService;

  const _ParentNotificationDialog({
    required this.student,
    required this.classData,
    required this.teacherService,
  });

  @override
  State<_ParentNotificationDialog> createState() => _ParentNotificationDialogState();
}

class _ParentNotificationDialogState extends State<_ParentNotificationDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ tiêu đề và nội dung')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // Get student ID
      final studentId = widget.student['userId'] ?? widget.student['studentId'] ?? widget.student['id'];
      final classId = widget.classData['classId'] ?? widget.classData['id'];

      if (studentId == null) {
        throw Exception('Không tìm thấy thông tin học sinh');
      }

      if (classId == null) {
        throw Exception('Không tìm thấy thông tin lớp học');
      }

      // Fetch student detail to get parentId
      final studentDetail = await widget.teacherService.getStudentDetail(studentId);
      
      if (studentDetail == null) {
        throw Exception('Không thể tải thông tin học sinh');
      }

      // Extract parentId from student detail
      final parentId = studentDetail['parentId'] ?? studentDetail['parent_id'];

      if (parentId == null) {
        throw Exception('Học sinh chưa có phụ huynh trong hệ thống');
      }

      final success = await widget.teacherService.notifyParent(
        parentId: parentId,
        classId: classId,
        title: title,
        message: message,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi thông báo đến phụ huynh'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = widget.student['fullName'] ?? widget.student['name'] ?? 'Phụ huynh';

    return AlertDialog(
      title: Text('Thông báo phụ huynh: $studentName'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề',
                border: OutlineInputBorder(),
                hintText: 'Nhập tiêu đề thông báo',
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Nội dung',
                border: OutlineInputBorder(),
                hintText: 'Nhập nội dung thông báo',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendNotification,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Gửi'),
        ),
      ],
    );
  }
}

class _GradeUpdateDialog extends StatefulWidget {
  final Map<String, dynamic> student;
  final Map<String, dynamic> classData;
  final TeacherService teacherService;

  const _GradeUpdateDialog({
    required this.student,
    required this.classData,
    required this.teacherService,
  });

  @override
  State<_GradeUpdateDialog> createState() => _GradeUpdateDialogState();
}

/// Formatter để kiểm soát nhập liệu điểm số (chỉ số và dấu chấm, tối đa 10).
class _GradeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Chỉ cho phép nhập số và một dấu chấm
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)) {
      return oldValue;
    }

    // Phân tích giá trị số
    try {
      final value = double.parse(newValue.text);
      if (value < 0 || value > 10) {
        return oldValue;
      }
    } catch (e) {
      // Nếu phân tích lỗi (ví dụ chỉ có dấu "."), cho phép nếu là tiền tố hợp lệ
      if (newValue.text == '.') return newValue; 
      return oldValue;
    }

    return newValue;
  }
}

class _GradeUpdateDialogState extends State<_GradeUpdateDialog> {
  // ... (controllers and state variables remain same)
  final TextEditingController _score1Controller = TextEditingController();
  final TextEditingController _score2Controller = TextEditingController();
  final TextEditingController _score3Controller = TextEditingController();
  double? _finalScore;
  int? _studentClassId;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadStudentDetail();
    _score1Controller.addListener(_calculateFinalScore);
    _score2Controller.addListener(_calculateFinalScore);
    _score3Controller.addListener(_calculateFinalScore);
  }

  @override
  void dispose() {
    _score1Controller.dispose();
    _score2Controller.dispose();
    _score3Controller.dispose();
    super.dispose();
  }

  /// Tính toán điểm trung bình dựa trên 3 cột điểm.
  void _calculateFinalScore() {
    double? s1 = double.tryParse(_score1Controller.text);
    double? s2 = double.tryParse(_score2Controller.text);
    double? s3 = double.tryParse(_score3Controller.text);

    if (s1 != null && s2 != null && s3 != null) {
      setState(() {
        _finalScore = (s1 + s2 + s3) / 3;
      });
    } else {
      setState(() {
        _finalScore = null;
      });
    }
  }
  
  // ... _loadStudentDetail remains same ...
  /// Tải thông tin chi tiết của học sinh để lấy điểm số hiện tại.
  Future<void> _loadStudentDetail() async {
    try {
      final studentId = widget.student['userId'] ?? widget.student['studentId'] ?? widget.student['id'];
      if (studentId != null) {
        final detail = await widget.teacherService.getStudentDetail(studentId);
        
        if (detail != null && mounted) {
          setState(() {
            // Mặc định lấy điểm ở cấp cao nhất nếu có (fallback)
            var s1 = detail['score1'] ?? detail['score_1'];
            var s2 = detail['score2'] ?? detail['score_2'];
            var s3 = detail['score3'] ?? detail['score_3'];
            
            // Tìm studentClassId và điểm số từ danh sách lớp học (studentClasses)
            if (detail['studentClasses'] is List) {
              final classes = detail['studentClasses'] as List;
              final currentClassId = widget.classData['classId'] ?? widget.classData['id'];
              for (var item in classes) {
                if (item is Map && item['classId'] == currentClassId) {
                  _studentClassId = item['studentClassId'];
                  // Ưu tiên lấy điểm từ bản ghi của lớp học cụ thể
                  s1 = item['score1'] ?? item['score_1'] ?? s1;
                  s2 = item['score2'] ?? item['score_2'] ?? s2;
                  s3 = item['score3'] ?? item['score_3'] ?? s3;
                  break;
                }
              }
            }
            
            _score1Controller.text = s1?.toString() ?? '';
            _score2Controller.text = s2?.toString() ?? '';
            _score3Controller.text = s3?.toString() ?? '';
            
            _isLoading = false;
          });
          _calculateFinalScore();
        }
      }
    } catch (e) {
      debugPrint('Error loading student detail: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Cập nhật điểm số lên server.
  Future<void> _updateGrades() async {
    if (_studentClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy thông tin lớp học')),
      );
      return;
    }

    // Không cần thông báo lỗi validation cụ thể vì input đã được giới hạn


    setState(() => _isUpdating = true);

    try {
      final Map<String, dynamic> scores = {
        'score1': double.tryParse(_score1Controller.text),
        'score2': double.tryParse(_score2Controller.text),
        'score3': double.tryParse(_score3Controller.text),
        'finalScore': _finalScore,
      };

      final success = await widget.teacherService.updateStudentGrade(_studentClassId!, scores);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật điểm thành công')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật điểm: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nhập điểm: ${widget.student['fullName'] ?? widget.student['name']}'),
      content: _isLoading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField('Cột 1', _score1Controller),
                  const SizedBox(height: 12),
                  _buildTextField('Cột 2', _score2Controller),
                  const SizedBox(height: 12),
                  _buildTextField('Cột 3', _score3Controller),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Điểm trung bình:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        _finalScore != null ? _finalScore!.toStringAsFixed(1) : '---',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: (_isLoading || _isUpdating) ? null : _updateGrades,
          child: _isUpdating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Cập nhật'),
        ),
      ],
    );
  }

  /// Widget hiển thị ô nhập liệu điểm số.
  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        _GradeInputFormatter(),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
