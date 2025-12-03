import 'package:app_quan_ly_tuyen_sinh/services/teacher/grade_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class GradeEntryScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  final List<Map<String, dynamic>> students;

  const GradeEntryScreen({
    super.key,
    required this.classData,
    required this.students,
  });

  @override
  State<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends State<GradeEntryScreen> {
  final GradeService _gradeService = GradeService();
  final Map<int, Map<String, TextEditingController>> _controllers = {};
  final Map<int, Set<String>> _existingGrades = {}; // Theo dõi các trường đã có điểm (chỉ đọc)
  List<Map<String, dynamic>> _sortedStudents = [];
  
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _sortStudents();
    _initializeControllers();
    _loadGrades();
  }

  /// Sắp xếp danh sách học sinh theo tên (First Name).
  void _sortStudents() {
    _sortedStudents = List.from(widget.students);
    _sortedStudents.sort((a, b) {
      final nameA = (a['fullName'] ?? a['name'] ?? '').toString().trim();
      final nameB = (b['fullName'] ?? b['name'] ?? '').toString().trim();
      
      final firstNameA = nameA.split(' ').last;
      final firstNameB = nameB.split(' ').last;
      
      return firstNameA.compareTo(firstNameB);
    });
  }

  @override
  void dispose() {
    // Giải phóng tất cả các controller
    for (var studentControllers in _controllers.values) {
      for (var controller in studentControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  /// Khởi tạo controller nhập liệu cho từng học sinh.
  void _initializeControllers() {
    for (var student in _sortedStudents) {
      final studentId = student['userId'] ?? student['studentId'] ?? student['id'];
      if (studentId != null) {
        _controllers[studentId] = {
          'score_1': TextEditingController(),
          'score_2': TextEditingController(),
          'score_3': TextEditingController(),
        };
      }
    }
  }

  /// Tải dữ liệu điểm số hiện có của lớp học.
  Future<void> _loadGrades() async {
    setState(() => _isLoading = true);
    
    try {
      final classId = widget.classData['classId'] ?? widget.classData['id'];
      if (classId != null) {
        final grades = await _gradeService.getClassGrades(classId);
        
        // Điền dữ liệu điểm vào các controller tương ứng
        for (var gradeData in grades) {
          final studentId = gradeData['studentId'] ?? gradeData['userId'];
          if (studentId != null && _controllers.containsKey(studentId)) {
            // Đánh dấu các trường đã có dữ liệu
            _existingGrades[studentId] = {};
            
            final score1 = gradeData['score1'] ?? gradeData['score_1'];
            final score2 = gradeData['score2'] ?? gradeData['score_2'];
            final score3 = gradeData['score3'] ?? gradeData['score_3'];
            
            debugPrint('Loading grades for student $studentId: score1=$score1, score2=$score2, score3=$score3');
            
            if (score1 != null) {
              _controllers[studentId]!['score_1']!.text = _formatScore(score1);
              _existingGrades[studentId]!.add('score_1');
            }
            if (score2 != null) {
              _controllers[studentId]!['score_2']!.text = _formatScore(score2);
              _existingGrades[studentId]!.add('score_2');
            }
            if (score3 != null) {
              _controllers[studentId]!['score_3']!.text = _formatScore(score3);
              _existingGrades[studentId]!.add('score_3');
            }
          }
        }
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading grades: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Định dạng điểm số hiển thị (loại bỏ .0 nếu là số nguyên).
  String _formatScore(dynamic score) {
    if (score == null) return '';
    if (score is num) {
      // Format to 1 decimal place, remove trailing .0
      final formatted = score.toStringAsFixed(1);
      return formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted;
    }
    return score.toString();
  }

  /// Lưu điểm số đã nhập lên server.
  Future<void> _saveGrades() async {
    // Hiển thị hộp thoại xác nhận trước khi lưu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận lưu điểm'),
        content: const Text('Bạn có chắc chắn muốn lưu điểm cho lớp học này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    
    try {
      final classId = widget.classData['classId'] ?? widget.classData['id'];
      if (classId == null) {
        throw Exception('Class ID not found');
      }

      final studentGrades = <Map<String, dynamic>>[];
      
      for (var student in _sortedStudents) {
        final studentId = student['userId'] ?? student['studentId'] ?? student['id'];
        if (studentId != null && _controllers.containsKey(studentId)) {
          final controllers = _controllers[studentId]!;
          
          // Phân tích điểm số từ input
          final score1 = double.tryParse(controllers['score_1']!.text.trim());
          final score2 = double.tryParse(controllers['score_2']!.text.trim());
          final score3 = double.tryParse(controllers['score_3']!.text.trim());
          
          // Chỉ thêm vào danh sách nếu có ít nhất một cột điểm được nhập
          if (score1 != null || score2 != null || score3 != null) {
            studentGrades.add({
              'studentId': studentId,
              'studentClassId': student['studentClassId'] ?? student['id'],
              'enrollmentDate': student['enrollmentDate'] ?? student['createdAt'] ?? DateFormat('dd-MM-yyyy').format(DateTime.now()),
              'score1': score1,
              'score2': score2,
              'score3': score3,
            });
          }
        }
      }

      if (studentGrades.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa nhập điểm nào')),
          );
        }
        return;
      }

      // Lưu điểm cho từng học sinh
      int successCount = 0;
      int failCount = 0;
      
      for (var gradeData in studentGrades) {
        try {
          // Tính điểm trung bình (finalScore) CHỈ KHI có đủ 3 cột điểm
          final score1 = gradeData['score1'];
          final score2 = gradeData['score2'];
          final score3 = gradeData['score3'];
          
          final double? finalScore;
          if (score1 != null && score2 != null && score3 != null) {
            // Tính trung bình cộng và làm tròn đến 1 chữ số thập phân
            final average = (score1 + score2 + score3) / 3.0;
            finalScore = double.parse(average.toStringAsFixed(1));
          } else {
            finalScore = null;
          }
          
          await _gradeService.updateGrades(
            studentId: gradeData['studentId'],
            classId: classId,
            grades: {
              'studentClassId': gradeData['studentClassId'],
              'enrollmentDate': gradeData['enrollmentDate'],
              'status': 'ACTIVE',
              'score1': gradeData['score1'],
              'score2': gradeData['score2'],
              'score3': gradeData['score3'],
              'finalScore': finalScore,
              'attendanceRate': null,
              'notes': null,
            },
          );
          successCount++;
        } catch (e) {
          debugPrint('Failed to save grade for student ${gradeData['studentId']}: $e');
          failCount++;
        }
      }

      if (mounted) {
        if (failCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã lưu điểm thành công cho $successCount học viên!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lưu thành công: $successCount, Thất bại: $failCount'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu điểm: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final className = widget.classData['name'] ?? widget.classData['className'] ?? 'Lớp học';

    return Scaffold(
      appBar: AppBar(
        title: Text('Nhập điểm - $className'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Hàng tiêu đề
                Container(
                  color: Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text('STT', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('Tên', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: Text('Cột 1', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: Text('Cột 2', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: Text('Cột 3', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                
                // Danh sách học sinh
                Expanded(
                  child: ListView.builder(
                    itemCount: _sortedStudents.length,
                    itemBuilder: (context, index) {
                      return _buildStudentRow(index, _sortedStudents[index]);
                    },
                  ),
                ),

                // Nút Lưu ở dưới cùng
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: (_isSaving || _allStudentsHaveCompleteGrades() || !_allStudentsHaveGrades()) ? null : _saveGrades,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.blue,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Lưu điểm',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Kiểm tra xem tất cả học sinh đã có đủ 3 cột điểm chưa.
  bool _allStudentsHaveCompleteGrades() {
    for (var student in _sortedStudents) {
      final studentId = student['userId'] ?? student['studentId'] ?? student['id'];
      if (studentId != null && _existingGrades.containsKey(studentId)) {
        final existing = _existingGrades[studentId]!;
        // Check if student has all 3 scores
        if (!(existing.contains('score_1') && existing.contains('score_2') && existing.contains('score_3'))) {
          return false; // Có ít nhất một học sinh chưa đủ điểm
        }
      } else {
        return false; // Học sinh chưa có điểm nào
      }
    }
    return true; // Tất cả học sinh đã có đủ điểm
  }

  /// Kiểm tra tính hợp lệ của dữ liệu nhập (logic nhập theo cột).
  bool _allStudentsHaveGrades() {
    // Kiểm tra từng cột: nếu một cột có dữ liệu MỚI (không phải có sẵn), TẤT CẢ học sinh phải có dữ liệu ở cột đó
    
    // Đếm số học sinh có dữ liệu MỚI ở mỗi cột
    int score1NewCount = 0;
    int score2NewCount = 0;
    int score3NewCount = 0;
    
    // Đếm số học sinh CÓ THỂ nhập liệu ở mỗi cột (chưa có dữ liệu sẵn)
    int score1AvailableCount = 0;
    int score2AvailableCount = 0;
    int score3AvailableCount = 0;
    
    for (var student in _sortedStudents) {
      final studentId = student['userId'] ?? student['studentId'] ?? student['id'];
      if (studentId == null || !_controllers.containsKey(studentId)) continue;
      
      final controllers = _controllers[studentId]!;
      final existingGrades = _existingGrades[studentId] ?? {};
      
      // Kiểm tra khả năng nhập liệu
      if (!existingGrades.contains('score_1')) score1AvailableCount++;
      if (!existingGrades.contains('score_2')) score2AvailableCount++;
      if (!existingGrades.contains('score_3')) score3AvailableCount++;
      
      // Kiểm tra dữ liệu mới nhập
      if (!existingGrades.contains('score_1') && controllers['score_1']!.text.trim().isNotEmpty) {
        score1NewCount++;
      }
      if (!existingGrades.contains('score_2') && controllers['score_2']!.text.trim().isNotEmpty) {
        score2NewCount++;
      }
      if (!existingGrades.contains('score_3')) {
        final text = controllers['score_3']!.text.trim();
        if (text.isNotEmpty) {
          score3NewCount++;
        }
      }
    }
    
    // Nếu một cột có bất kỳ dữ liệu MỚI nào, TẤT CẢ học sinh khả dụng phải có dữ liệu ở cột đó
    if (score1NewCount > 0 && score1NewCount < score1AvailableCount) return false;
    if (score2NewCount > 0 && score2NewCount < score2AvailableCount) return false;
    if (score3NewCount > 0 && score3NewCount < score3AvailableCount) return false;
    
    // Phải có ít nhất một cột có dữ liệu MỚI đầy đủ
    if (score1NewCount == 0 && score2NewCount == 0 && score3NewCount == 0) return false;
    
    return true;
  }

  /// Widget hiển thị một hàng nhập điểm cho học sinh.
  Widget _buildStudentRow(int index, Map<String, dynamic> student) {
    final studentName = student['fullName'] ?? student['name'] ?? 'Học viên';
    final studentId = student['userId'] ?? student['studentId'] ?? student['id'];

    if (studentId == null || !_controllers.containsKey(studentId)) {
      return const SizedBox.shrink();
    }

    final controllers = _controllers[studentId]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              studentName,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: _buildScoreField(studentId, 'score_1', controllers['score_1']!)),
          Expanded(child: _buildScoreField(studentId, 'score_2', controllers['score_2']!)),
          Expanded(child: _buildScoreField(studentId, 'score_3', controllers['score_3']!)),
        ],
      ),
    );
  }

  /// Widget hiển thị ô nhập điểm.
  Widget _buildScoreField(int studentId, String fieldName, TextEditingController controller) {
    final bool isReadOnly = _existingGrades[studentId]?.contains(fieldName) ?? false;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: controller,
        enabled: !isReadOnly,
        readOnly: isReadOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
        ],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: isReadOnly ? Colors.grey.shade600 : Colors.black,
          fontWeight: isReadOnly ? FontWeight.w500 : FontWeight.normal,
        ),
        decoration: InputDecoration(
          hintText: '-',
          filled: isReadOnly,
          fillColor: isReadOnly ? Colors.grey.shade100 : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: isReadOnly ? Colors.grey.shade200 : Colors.grey.shade300),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
        ),
        onChanged: isReadOnly ? null : (value) {
          // Validate điểm số (0-10)
          final score = double.tryParse(value);
          if (score != null && (score < 0 || score > 10)) {
            controller.text = '';
          }
          // Rebuild để cập nhật trạng thái nút Lưu
          setState(() {});
        },
      ),
    );
  }
}
