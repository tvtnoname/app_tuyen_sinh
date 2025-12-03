import 'package:app_quan_ly_tuyen_sinh/services/teacher/attendance_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  final List<Map<String, dynamic>> students;
  final bool isUpdateMode;

  const AttendanceScreen({
    super.key,
    required this.classData,
    required this.students,
    this.isUpdateMode = false,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  
  late DateTime _selectedDate;
  final Map<int, String> _attendanceStatus = {}; // studentId -> status (Lưu trạng thái điểm danh)
  final Map<int, String> _permissionReasons = {}; // studentId -> reason (Lưu lý do nghỉ phép)
  
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isAlreadyTaken = false;
  int? _todayScheduleId;

  List<Map<String, dynamic>> _sortedStudents = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _sortStudents();
    _initializeAttendance();
    _checkAndLoadAttendance();
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

  /// Khởi tạo trạng thái điểm danh mặc định.
  void _initializeAttendance() {
    // Mặc định tất cả là CÓ MẶT (PRESENT)
    for (var student in _sortedStudents) {
      final studentId = student['userId'] ?? student['studentId'] ?? student['id'];
      if (studentId != null) {
        _attendanceStatus[studentId] = 'PRESENT';
        _permissionReasons[studentId] = '';
      }
    }
  }

  Future<void> _checkAndLoadAttendance() async {
    setState(() => _isLoading = true);
    
    try {
      final classId = widget.classData['classId'] ?? widget.classData['id'];
      
      // 1. Xác định ID lịch học cho ngày đã chọn
      _todayScheduleId = _getScheduleIdForDate(_selectedDate);
      
      if (_todayScheduleId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không có lịch học cho ngày này')),
          );
          setState(() {
             _isLoading = false;
             _isAlreadyTaken = false;
          });
        }
        return;
      }

      // 2. Kiểm tra xem đã điểm danh chưa
      final records = await _attendanceService.getAttendance(
        classId: classId,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      );
      
      if (records.isNotEmpty) {
        _isAlreadyTaken = true;
        // Điền dữ liệu đã có vào bảng
        for (var record in records) {
          final studentId = record['studentId'] ?? record['userId'];
          final status = record['status'];
          final reason = record['permissionReason'];
          if (studentId != null && status != null) {
            _attendanceStatus[studentId] = status;
            if (reason != null) {
              _permissionReasons[studentId] = reason;
            }
          }
        }
      } else {
        _isAlreadyTaken = false;
        // Reset về mặc định nếu chưa điểm danh
        _initializeAttendance();
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Lấy ID lịch học dựa trên ngày đã chọn.
  int? _getScheduleIdForDate(DateTime date) {
    // Ánh xạ thứ trong Dart (1=T2..7=CN) sang dayOfWeek của API
    int apiDay = date.weekday; 
    
    List schedules = [];
    if (widget.classData['classSchedules'] is List) {
      schedules = widget.classData['classSchedules'];
    } else if (widget.classData['clazz'] is Map && widget.classData['clazz']['classSchedules'] is List) {
      schedules = widget.classData['clazz']['classSchedules'];
    }

    for (var s in schedules) {
      if (s['dayOfWeek'] == apiDay) {
        return s['scheduleId'];
      }
    }
    return null;
  }

  /// Chọn ngày điểm danh.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _checkAndLoadAttendance();
    }
  }

  /// Xác nhận và lưu thông tin điểm danh.
  Future<void> _confirmAndSave() async {
    // Kiểm tra xem có lịch học hợp lệ cho ngày hôm nay không
    if (_todayScheduleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có lịch học vào ngày này, không thể cập nhật.')),
      );
      return;
    }
    
    final int scheduleIdToUse = _todayScheduleId!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isUpdateMode ? 'Cập nhật điểm danh' : 'Xác nhận điểm danh'),
        content: Text(widget.isUpdateMode 
            ? 'Bạn có chắc chắn muốn cập nhật điểm danh cho ngày này?' 
            : 'Bạn có chắc chắn muốn lưu điểm danh? Sau khi lưu sẽ không thể thay đổi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _saveAttendance(scheduleIdToUse);
    }
  }
  
  /// Gọi API để lưu điểm danh.
  Future<void> _saveAttendance(int scheduleId) async {
    setState(() => _isSaving = true);
    
    try {
      final classId = widget.classData['classId'] ?? widget.classData['id'];
      final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
      final apiDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate); // Dùng cho PATCH
      
      // Duyệt qua danh sách học sinh và lưu từng người một
      List<Future> futures = [];
      for (var student in _sortedStudents) {
        final studentId = student['userId'] ?? student['studentId'] ?? student['id'];
        if (studentId != null) {
          final status = _attendanceStatus[studentId] ?? 'PRESENT';
          final reason = _permissionReasons[studentId];
          
          // Luôn dùng PATCH nếu ở chế độ cập nhật HOẶC đã điểm danh rồi
          if (widget.isUpdateMode || _isAlreadyTaken) {
             // Dùng PATCH để cập nhật
             futures.add(_attendanceService.updateStudentAttendance(
               scheduleId: scheduleId,
               classId: classId,
               studentId: studentId,
               date: apiDateStr,
               status: status,
               permissionReason: reason,
             ));
          } else {
             // Dùng POST để tạo mới
             futures.add(_attendanceService.markStudentAttendance(
               classId: classId,
               scheduleId: scheduleId,
               studentId: studentId,
               date: dateStr,
               status: status,
               permissionReason: reason,
             ));
          }
        }
      }

      await Future.wait(futures);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isUpdateMode ? 'Cập nhật thành công!' : 'Đã lưu điểm danh thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu điểm danh: ${e.toString().replaceAll('Exception: ', '')}'),
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
    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    
    // Xác định xem nút lưu có bị vô hiệu hóa không
    // Vô hiệu hóa nếu: Đang lưu HOẶC Không có lịch học
    final bool isButtonDisabled = _isSaving || _todayScheduleId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isUpdateMode || _isAlreadyTaken ? 'Cập nhật điểm danh' : 'Điểm danh - $className'),
        elevation: 0,
        actions: [
          if (widget.isUpdateMode || _isAlreadyTaken)
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _selectDate(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // ... (giữ nguyên phần Header)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ngày: $dateStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_isAlreadyTaken)
                  const Chip(
                    label: Text('Đã điểm danh'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  )
                else if (_todayScheduleId == null)
                  const Chip(
                    label: Text('Không có lịch'),
                    backgroundColor: Colors.orange,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
          ),

          // ... (giữ nguyên phần Tiêu đề bảng)
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Row(
              children: [
                SizedBox(width: 40, child: Text('STT', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Tên học viên', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text('Có mặt', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text('Vắng', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text('Trễ', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Lý do', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // Danh sách học sinh
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _sortedStudents.length,
                    itemBuilder: (context, index) {
                      return _buildStudentRow(index, _sortedStudents[index]);
                    },
                  ),
          ),

          // Nút Lưu - Luôn hiển thị, chỉ vô hiệu hóa nếu cần
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
              onPressed: isButtonDisabled ? null : _confirmAndSave,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: isButtonDisabled ? Colors.grey : Colors.blue,
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
                  : Text(
                      isButtonDisabled 
                          ? 'Đang tải...' 
                          : (_isAlreadyTaken || widget.isUpdateMode ? 'Cập nhật' : 'Lưu điểm danh'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị một hàng thông tin học sinh.
  Widget _buildStudentRow(int index, Map<String, dynamic> student) {
    final studentName = student['fullName'] ?? student['name'] ?? 'Học viên';
    final studentId = student['userId'] ?? student['studentId'] ?? student['id'];
    
    if (studentId == null) return const SizedBox.shrink();

    final currentStatus = _attendanceStatus[studentId];
    // Cho phép chỉnh sửa ngay cả khi đã điểm danh (để cập nhật)
    final isReadOnly = false;
    
    // Chỉ cho phép nhập lý do nếu Vắng hoặc Trễ
    final isReasonEnabled = !isReadOnly && (currentStatus == 'ABSENT' || currentStatus == 'LATE');

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('${index + 1}', textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text(studentName, style: const TextStyle(fontSize: 14)),
          ),
          _buildCheckbox(studentId, 'PRESENT', currentStatus, isReadOnly),
          _buildCheckbox(studentId, 'ABSENT', currentStatus, isReadOnly),
          _buildCheckbox(studentId, 'LATE', currentStatus, isReadOnly),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextFormField(
                initialValue: _permissionReasons[studentId],
                enabled: isReasonEnabled,
                decoration: InputDecoration(
                  hintText: 'Lý do...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: !isReasonEnabled,
                  fillColor: !isReasonEnabled ? Colors.grey.shade100 : Colors.white,
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (value) {
                  _permissionReasons[studentId] = value;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị checkbox (radio button) cho trạng thái điểm danh.
  Widget _buildCheckbox(int studentId, String statusValue, String? currentStatus, bool isReadOnly) {
    final isChecked = currentStatus == statusValue;
    
    return Expanded(
      child: Center(
        child: Checkbox(
          value: isChecked,
          onChanged: isReadOnly
              ? null
              : (bool? value) {
                  if (value == true) {
                    setState(() {
                      _attendanceStatus[studentId] = statusValue;
                      // Xóa lý do nếu chuyển sang CÓ MẶT? Tùy chọn.
                      // Người dùng yêu cầu "cho phép nhập nếu vắng/trễ", không nói xóa.
                    });
                  }
                },
          activeColor: Colors.blue,
          shape: const CircleBorder(), // Làm cho giống radio button
        ),
      ),
    );
  }
}
