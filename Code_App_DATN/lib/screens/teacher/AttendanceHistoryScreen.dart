import 'package:app_quan_ly_tuyen_sinh/services/teacher/attendance_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  final List<Map<String, dynamic>> students;

  const AttendanceHistoryScreen({
    super.key,
    required this.classData,
    required this.students,
  });

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _sortedStudents = [];
  
  // Dữ liệu cho bảng ma trận
  List<String> _dates = [];
  // Map<StudentId, Map<Date, Status>>: Lưu trạng thái điểm danh
  Map<int, Map<String, String>> _attendanceMap = {};
  // Map<StudentId, Map<Date, AttendanceId>>: Lưu ID bản ghi điểm danh để cập nhật
  Map<int, Map<String, int>> _attendanceIdMap = {};

  @override
  void initState() {
    super.initState();
    _sortStudents();
    _loadAttendanceHistory();
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

  /// Tải lịch sử điểm danh của lớp học.
  Future<void> _loadAttendanceHistory() async {
    setState(() => _isLoading = true);
    try {
      final classId = widget.classData['classId'] ?? widget.classData['id'];
      if (classId != null) {
        final list = await _attendanceService.getClassAttendanceHistory(classId);
        
        // Xử lý dữ liệu trả về từ API
        final Set<String> dateSet = {};
        final Map<int, Map<String, String>> map = {};
        final Map<int, Map<String, int>> idMap = {};

        for (var record in list) {
          final rawDate = record['attendanceDate'];
          final studentId = record['studentId'];
          final status = record['status'];
          final attendanceId = record['attendanceId'] ?? record['id'];

          if (rawDate != null && studentId != null && status != null) {
            // Chuẩn hóa định dạng ngày về dd/MM/yyyy
            String normalizedDate = rawDate.toString();
            DateTime? dt = _parseDate(normalizedDate);
            
            if (dt != null) {
              normalizedDate = DateFormat('dd/MM/yyyy').format(dt);
              dateSet.add(normalizedDate);
              
              if (!map.containsKey(studentId)) {
                map[studentId] = {};
                idMap[studentId] = {};
              }
              map[studentId]![normalizedDate] = status;
              if (attendanceId != null) {
                idMap[studentId]![normalizedDate] = attendanceId;
              }
            }
          }
        }

        // Sắp xếp các ngày theo thứ tự thời gian
        final sortedDates = dateSet.toList()
          ..sort((a, b) {
            final dateA = DateFormat('dd/MM/yyyy').parse(a);
            final dateB = DateFormat('dd/MM/yyyy').parse(b);
            return dateA.compareTo(dateB);
          });

        setState(() {
          _dates = sortedDates;
          _attendanceMap = map;
          _attendanceIdMap = idMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading attendance history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  /// Phân tích chuỗi ngày tháng thành đối tượng DateTime.
  DateTime? _parseDate(String dateStr) {
    try {
      // Try dd-MM-yyyy
      return DateFormat('dd-MM-yyyy').parse(dateStr);
    } catch (_) {}
    
    try {
      // Try dd/MM/yyyy
      return DateFormat('dd/MM/yyyy').parse(dateStr);
    } catch (_) {}

    try {
      // Try ISO 8601
      return DateTime.parse(dateStr);
    } catch (_) {}
    
    return null;
  }

  /// Hiển thị hộp thoại cập nhật điểm danh cho một học sinh.
  Future<void> _showUpdateDialog(Map<String, dynamic> student) async {
    final studentId = student['userId'] ?? student['studentId'] ?? student['id'];
    final studentName = student['fullName'] ?? 'Học viên';
    
    if (studentId == null) return;

    final studentAttendance = _attendanceMap[studentId] ?? {};
    final studentAttendanceIds = _attendanceIdMap[studentId] ?? {};

    // Lấy danh sách các ngày học sinh đã được điểm danh
    final availableDates = studentAttendance.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('dd/MM/yyyy').parse(a);
        final dateB = DateFormat('dd/MM/yyyy').parse(b);
        return dateB.compareTo(dateA); // Newest first
      });

    if (availableDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Học viên này chưa có dữ liệu điểm danh')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => _StudentAttendanceUpdateDialog(
        studentName: studentName,
        availableDates: availableDates,
        initialStatusMap: studentAttendance,
        attendanceIdMap: studentAttendanceIds,
        onUpdate: (attendanceId, newStatus, reason) async {
          await _attendanceService.updateAttendanceRecord(
            attendanceId: attendanceId,
            status: newStatus,
            permissionReason: reason,
          );
          // Tải lại dữ liệu sau khi cập nhật thành công
          _loadAttendanceHistory();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final className = widget.classData['name'] ?? 'Lớp học';

    return Scaffold(
      appBar: AppBar(
        title: Text('Lịch sử điểm danh - $className'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dates.isEmpty
              ? const Center(child: Text('Chưa có dữ liệu điểm danh'))
              : Column(
                  children: [
                    Expanded(child: _buildMatrixTable()),
                    _buildSummarySection(),
                  ],
                ),
    );
  }

  /// Widget hiển thị phần tổng hợp số liệu.
  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Tổng số học viên', '${_sortedStudents.length}'),
          _buildSummaryItem('Tổng số buổi', '${_dates.length}'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Widget hiển thị bảng ma trận điểm danh.
  Widget _buildMatrixTable() {
    // Định nghĩa chiều rộng các cột
    final Map<int, TableColumnWidth> columnWidths = {
      0: const FixedColumnWidth(50), // STT
      1: const FixedColumnWidth(180), // Name (Wider for button)
    };
    
    // Thêm chiều rộng cho các cột ngày tháng
    for (int i = 0; i < _dates.length; i++) {
      columnWidths[i + 2] = const FixedColumnWidth(100);
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 230.0 + (_dates.length * 100.0), // Tổng chiều rộng bảng
          child: Column(
            children: [
              // Header cố định (Sticky Header)
              Table(
                columnWidths: columnWidths,
                border: TableBorder.all(color: Colors.grey.shade300),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.blue.shade100),
                    children: [
                      _buildHeaderCell('STT'),
                      _buildHeaderCell('Học viên'),
                      ..._dates.map((d) => _buildHeaderCell(d)),
                    ],
                  ),
                ],
              ),
              
              // Phần thân bảng có thể cuộn dọc
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Table(
                    columnWidths: columnWidths,
                    border: TableBorder.all(color: Colors.grey.shade300),
                    children: _sortedStudents.asMap().entries.map((entry) {
                      final index = entry.key;
                      final student = entry.value;
                      final studentId = student['userId'] ?? student['studentId'] ?? student['id'];
                      final studentName = student['fullName'] ?? 'Học viên $studentId';

                      return TableRow(
                        decoration: BoxDecoration(
                          color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                        ),
                        children: [
                          _buildCell((index + 1).toString(), align: TextAlign.center),
                          // Tên học sinh kèm nút chỉnh sửa
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            height: 50,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    studentName,
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_note, size: 24, color: Colors.blue),
                                  tooltip: 'Cập nhật điểm danh',
                                  onPressed: () => _showUpdateDialog(student),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                          ..._dates.map((date) {
                            final status = _attendanceMap[studentId]?[date];
                            return _buildStatusCell(status);
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget hiển thị ô tiêu đề cột.
  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      height: 50,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Widget hiển thị ô dữ liệu thông thường.
  Widget _buildCell(String text, {TextAlign align = TextAlign.left}) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
      height: 50, // Chiều cao cố định để các hàng đều nhau
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Widget hiển thị ô trạng thái điểm danh với màu sắc tương ứng.
  Widget _buildStatusCell(String? status) {
    String text = '-';
    Color color = Colors.grey;
    
    if (status == 'PRESENT') {
      text = 'Có mặt';
      color = Colors.green;
    } else if (status == 'ABSENT') {
      text = 'Vắng';
      color = Colors.red;
    } else if (status == 'LATE') {
      text = 'Trễ';
      color = Colors.orange;
    } else if (status == 'EXCUSED') {
      text = 'Có phép';
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      height: 50,
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _StudentAttendanceUpdateDialog extends StatefulWidget {
  final String studentName;
  final List<String> availableDates;
  final Map<String, String> initialStatusMap;
  final Map<String, int> attendanceIdMap;
  final Function(int, String, String?) onUpdate;

  const _StudentAttendanceUpdateDialog({
    required this.studentName,
    required this.availableDates,
    required this.initialStatusMap,
    required this.attendanceIdMap,
    required this.onUpdate,
  });

  @override
  State<_StudentAttendanceUpdateDialog> createState() => _StudentAttendanceUpdateDialogState();
}

class _StudentAttendanceUpdateDialogState extends State<_StudentAttendanceUpdateDialog> {
  late String _selectedDate;
  late String _selectedStatus;
  final TextEditingController _reasonController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.availableDates.first;
    _selectedStatus = widget.initialStatusMap[_selectedDate] ?? 'PRESENT';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showReason = _selectedStatus == 'ABSENT' || _selectedStatus == 'EXCUSED' || _selectedStatus == 'LATE';

    return AlertDialog(
      title: Text('Cập nhật: ${widget.studentName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn ngày:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDate,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: widget.availableDates.map((date) {
                return DropdownMenuItem(
                  value: date,
                  child: Text(date),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedDate = value;
                    _selectedStatus = widget.initialStatusMap[value] ?? 'PRESENT';
                    // Reset reason when changing date? Optional. keeping it for now.
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            const Text('Trạng thái:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'PRESENT', child: Text('Có mặt', style: TextStyle(color: Colors.green))),
                DropdownMenuItem(value: 'ABSENT', child: Text('Vắng', style: TextStyle(color: Colors.red))),
                DropdownMenuItem(value: 'LATE', child: Text('Trễ', style: TextStyle(color: Colors.orange))),
                DropdownMenuItem(value: 'EXCUSED', child: Text('Có phép', style: TextStyle(color: Colors.blue))),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedStatus = value;
                  });
                }
              },
            ),
            if (showReason) ...[
              const SizedBox(height: 16),
              const Text('Lý do nghỉ phép:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  hintText: 'Nhập lý do...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _handleUpdate,
          child: _isUpdating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Cập nhật'),
        ),
      ],
    );
  }

  Future<void> _handleUpdate() async {
    final attendanceId = widget.attendanceIdMap[_selectedDate];
    if (attendanceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy ID điểm danh cho ngày này')),
      );
      return;
    }

    setState(() => _isUpdating = true);
    try {
      await widget.onUpdate(
        attendanceId, 
        _selectedStatus, 
        (_selectedStatus == 'ABSENT' || _selectedStatus == 'EXCUSED') ? _reasonController.text : null
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật thành công'), backgroundColor: Colors.green),
        );
        widget.initialStatusMap[_selectedDate] = _selectedStatus;
        setState(() => _isUpdating = false);
        Navigator.pop(context); // Close dialog on success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isUpdating = false);
      }
    }
  }
}
