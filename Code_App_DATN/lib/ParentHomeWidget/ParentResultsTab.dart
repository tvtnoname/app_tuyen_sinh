import 'dart:async';
import 'package:flutter/material.dart';
import '../services/parent/parent_service.dart';
import 'package:intl/intl.dart';
import '../screens/parent/ParentNotificationScreen.dart';

/// Màn hình hiển thị kết quả học tập dành cho Phụ huynh.
/// Bao gồm 3 tab: Điểm số, Điểm danh và Thành tích.
class ParentResultsTab extends StatefulWidget {
  const ParentResultsTab({super.key});

  @override
  State<ParentResultsTab> createState() => ParentResultsTabState();
}

class ParentResultsTabState extends State<ParentResultsTab> with SingleTickerProviderStateMixin {
  final ParentService _parentService = ParentService();
  late TabController _tabController;
  
  bool _isLoading = true;
  Timer? _notificationTimer;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _children = [];
  Map<String, dynamic>? _selectedChild;
  
  List<Map<String, dynamic>> _attendances = [];
  List<Map<String, dynamic>> _achievements = [];
  
  // Dữ liệu điểm số phân loại
  List<Map<String, dynamic>> _currentCourses = [];
  List<Map<String, dynamic>> _completedCourses = [];
  int? _selectedSemesterId;
  int _scoreTabIndex = 0; // 0: Đang học, 1: Đã học

  // Dữ liệu điểm danh phân loại
  List<Map<String, dynamic>> _currentAttendances = [];
  List<Map<String, dynamic>> _completedAttendances = [];
  int? _selectedAttendanceClassId;
  int _attendanceTabIndex = 0; // 0: Đang học, 1: Đã học

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadChildren();
    _startNotificationTimer();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Khởi tạo timer để kiểm tra thông báo chưa đọc định kỳ.
  void _startNotificationTimer() {
    _fetchUnreadNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchUnreadNotifications();
    });
  }

  /// Lấy số lượng thông báo chưa đọc từ API.
  Future<void> _fetchUnreadNotifications() async {
    try {
      final notifs = await _parentService.getNotifications();
      
      // Count unread notifications where receiverType == "PARENT"
      final unreadCount = notifs.where((n) {
        final receiverType = (n['receiverType'] ?? n['receiver_type'] ?? '').toString().toUpperCase();
        final rawIsRead = n['isRead'] ?? n['is_read'];
        final isRead = rawIsRead == 1 || rawIsRead == true || rawIsRead == '1';
        
        return receiverType == 'PARENT' && !isRead;
      }).length;

      if (mounted) {
        setState(() => _unreadNotifications = unreadCount);
      }
    } catch (e) {
      debugPrint('Error fetching unread notifications: $e');
    }
  }

  /// Tải danh sách con em.
  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    try {
      final children = await _parentService.getChildren();
      if (mounted) {
        setState(() {
          _children = children;
          if (_children.isNotEmpty) {
            _selectedChild = _children.first;
            _loadStudentData(_selectedChild!['studentId'] ?? _selectedChild!['id']);
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading children: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isCourseActive(Map<String, dynamic> item) {
    // Cố gắng lấy endDate từ item hoặc từ clazz bên trong
    final clazz = item['clazz'] ?? {};
    var endDateStr = item['endDate']?.toString() ?? clazz['endDate']?.toString();
    
    if (endDateStr == null || endDateStr.isEmpty) return true;

    endDateStr = endDateStr.trim();
    try {
      DateTime? endDate;
      try {
        endDate = DateTime.parse(endDateStr);
      } catch (_) {
        try {
          endDate = DateFormat('dd/MM/yyyy').parse(endDateStr);
        } catch (_) {
           try {
             endDate = DateFormat('dd-MM-yyyy').parse(endDateStr);
           } catch (_) {}
        }
      }

      if (endDate == null) return true;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      
      return !end.isBefore(today);
    } catch (e) {
      return true;
    }
  }

  /// Tải dữ liệu chi tiết của học sinh (điểm danh, điểm số, thành tích).


  /// Tải lại dữ liệu (dùng cho tính năng kéo để làm mới).
  Future<void> reload() async {
    if (_selectedChild != null) {
      await _loadStudentData(_selectedChild!['studentId'] ?? _selectedChild!['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang tải lại kết quả học tập...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      await _loadChildren();
    }
  }

  List<Map<String, dynamic>> _getAvailableSemesters(List<Map<String, dynamic>> courses) {
    final Map<int, String> semesters = {};
    for (var item in courses) {
      final clazz = item['clazz'] ?? {};
      var semester = clazz['semester'];
      
      // Fallback to root semester if not in clazz
      if (semester == null) {
        semester = item['semester'];
      }

      if (semester is Map) {
        final id = semester['id'] ?? semester['semesterId'];
        final name = semester['name'] ?? semester['semesterName'];
        
        if (id != null && name != null) {
           int? semId;
           if (id is int) {
             semId = id;
           } else if (id is String) {
             semId = int.tryParse(id);
           }
           
           if (semId != null) {
             String displayName = name.toString();
             
             // Try to find academic year
             var academicYear = semester['academicYear'];
             if (academicYear == null && clazz['course'] is Map) {
                academicYear = clazz['course']['academicYear'];
             }
             
             if (academicYear != null) {
               final yearName = academicYear is Map ? (academicYear['name'] ?? academicYear['code']) : academicYear;
               if (yearName != null) {
                 displayName += ' - $yearName';
               }
             }
             
             semesters[semId] = displayName;
           }
        }
      }
    }
    return semesters.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: _children.isEmpty 
            ? const Text('Kết quả học tập')
            : Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.blue.shade100, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: ButtonTheme(
                    alignedDropdown: true,
                    child: DropdownButton<Map<String, dynamic>>(
                      value: _selectedChild,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blue),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                      items: _children.map((child) {
                        return DropdownMenuItem(
                          value: child,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blue.shade50,
                                child: const Icon(Icons.face_rounded, size: 18, color: Colors.blue),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                child['user']?['fullName'] ?? child['fullName'] ?? child['name'] ?? 'Học sinh',
                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      selectedItemBuilder: (BuildContext context) {
                        return _children.map((child) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blue.shade50,
                                child: const Icon(Icons.face_rounded, size: 18, color: Colors.blue),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                child['user']?['fullName'] ?? child['fullName'] ?? child['name'] ?? 'Học sinh',
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        }).toList();
                      },
                      onChanged: (Map<String, dynamic>? newValue) {
                        if (newValue != null && newValue != _selectedChild) {
                          setState(() => _selectedChild = newValue);
                          _loadStudentData(newValue['studentId'] ?? newValue['id']);
                        }
                      },
                    ),
                  ),
                ),
              ),

        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Điểm số'),
            Tab(text: 'Điểm danh'),
            Tab(text: 'Thành tích'),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  int? studentId;
                  if (_selectedChild != null) {
                    studentId = _selectedChild!['studentId'] ?? _selectedChild!['id'];
                  }
                  
                  if (studentId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParentNotificationScreen(studentId: studentId!),
                      ),
                    ).then((_) => _fetchUnreadNotifications());
                  }
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScoreList(),
          _buildAttendanceList(),
          _buildAchievementList(),
        ],
      ),
    );
  }

  /// Widget hiển thị danh sách điểm số.
  Widget _buildScoreList() {
    final filteredCompletedCourses = _selectedSemesterId == null
        ? _completedCourses
        : _completedCourses.where((c) {
            final clazz = c['clazz'] ?? {};
            var semester = clazz['semester'];
            if (semester == null) semester = c['semester'];
            
            if (semester is Map) {
              final id = semester['id'] ?? semester['semesterId'];
              if (id != null) {
                 int? semId;
                 if (id is int) semId = id;
                 else if (id is String) semId = int.tryParse(id);
                 return semId == _selectedSemesterId;
              }
            }
            return false;
          }).toList();

    final displayList = _scoreTabIndex == 0 ? _currentCourses : filteredCompletedCourses;

    return Column(
      children: [
        // Toggle Buttons
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _scoreTabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _scoreTabIndex == 0 ? Colors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      'Đang học',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _scoreTabIndex == 0 ? Colors.white : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _scoreTabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _scoreTabIndex == 1 ? Colors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      'Đã học',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _scoreTabIndex == 1 ? Colors.white : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Semester Filter (Only for "Đã học")
        if (_scoreTabIndex == 1 && _completedCourses.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Lọc theo học kỳ:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isDense: true,
                      hint: const Text('Tất cả', style: TextStyle(fontSize: 13)),
                      value: _selectedSemesterId,
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Tất cả', style: TextStyle(fontSize: 13)),
                        ),
                        ..._getAvailableSemesters(_completedCourses).map((sem) {
                          return DropdownMenuItem<int>(
                            value: sem['id'],
                            child: Text(sem['name'], style: const TextStyle(fontSize: 13)),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedSemesterId = val;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

        // List
        Expanded(
          child: displayList.isEmpty
              ? Center(child: Text(_scoreTabIndex == 0 ? 'Không có môn đang học' : 'Không có môn đã học'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    final clazz = item['clazz'] ?? {};
                    final subjectName = clazz['subject'] is Map ? clazz['subject']['name'] : (clazz['name'] ?? 'Môn học');
                    final className = clazz['name'] ?? clazz['code'] ?? '';
                    
                    // Semester info
                    final semester = clazz['semester'];
                    final semesterName = semester is Map ? semester['name'] : null;
                    
                    // End Date info
                    var endDate = item['endDate'] ?? clazz['endDate'];
                    // Convert date format from YYYY-MM-DD to DD-MM-YYYY
                    if (endDate != null && endDate.toString().isNotEmpty) {
                      final parts = endDate.toString().split('-');
                      if (parts.length == 3) {
                        endDate = '${parts[2]}-${parts[1]}-${parts[0]}';
                      }
                    }

                    final score1 = item['score1'] ?? 0.0;
                    final score2 = item['score2'] ?? 0.0;
                    final score3 = item['score3'] ?? 0.0;
                    final finalScore = item['finalScore'] ?? 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subjectName + (semesterName != null ? ' - $semesterName' : ''),
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                      ),
                                      if (endDate != null && endDate.toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Expanded(
                                            child: Row(
                                              children: [
                                                Icon(Icons.event_busy, size: 14, color: Colors.red.shade400),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    'Kết thúc: $endDate', 
                                                    style: TextStyle(color: Colors.red.shade400, fontSize: 13),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (className.isNotEmpty && className != subjectName)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      className,
                                      style: TextStyle(fontSize: 14, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildScoreItem('Điểm 1', score1),
                                _buildScoreItem('Điểm 2', score2),
                                _buildScoreItem('Điểm 3', score3),
                                _buildScoreItem('Cuối kỳ', finalScore, isBold: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Widget hiển thị một ô điểm số.
  Widget _buildScoreItem(String label, dynamic score, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isBold ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isBold ? Colors.red.shade100 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            score.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? Colors.red : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }



  /// Tải dữ liệu chi tiết của học sinh (điểm danh, điểm số, thành tích).
  Future<void> _loadStudentData(int studentId) async {
    setState(() => _isLoading = true);
    try {
      final data = await _parentService.getStudentDetail(studentId);
      if (data != null) {
        if (mounted) {
          setState(() {
            final allAttendances = List<Map<String, dynamic>>.from(
              data['attendance'] ?? data['attendances'] ?? data['studentAttendances'] ?? []
            );
            
            // Sort attendances by date descending (newest first)
            allAttendances.sort((a, b) {
              try {
                final dateA = DateFormat('dd-MM-yyyy').parse(a['attendanceDate']);
                final dateB = DateFormat('dd-MM-yyyy').parse(b['attendanceDate']);
                return dateB.compareTo(dateA);
              } catch (e) {
                return 0;
              }
            });

            _achievements = List<Map<String, dynamic>>.from(
              data['studentAchievements'] ?? data['achievements'] ?? []
            );
            
            final allClasses = List<Map<String, dynamic>>.from(
              data['studentClasses'] ?? data['classes'] ?? data['transcript'] ?? []
            );

            // Categorize Courses
            _currentCourses = [];
            _completedCourses = [];
            for (var c in allClasses) {
              if (_isCourseActive(c)) {
                _currentCourses.add(c);
              } else {
                _completedCourses.add(c);
              }
            }

            // Categorize Attendances
            _currentAttendances = [];
            _completedAttendances = [];
            
            // Helper to find class info for an attendance item
            Map<String, dynamic>? findClassForAttendance(Map<String, dynamic> att) {
               if (att['clazz'] is Map) return att['clazz'];
               final classId = att['classId'];
               if (classId != null) {
                 return allClasses.firstWhere(
                   (c) => (c['classId'] ?? c['id']) == classId, 
                   orElse: () => <String, dynamic>{}
                 );
               }
               return null;
            }

            for (var att in allAttendances) {
               final clazz = findClassForAttendance(att);
               
               bool isActive = true;
               if (clazz != null && clazz.isNotEmpty) {
                  Map<String, dynamic> wrapper = {};
                  if (clazz.containsKey('clazz')) {
                    wrapper = clazz;
                  } else {
                    wrapper = {'clazz': clazz};
                  }
                  isActive = _isCourseActive(wrapper);
               }
               
               // Inject class info into attendance item for display if missing
               if (att['clazz'] == null && clazz != null && clazz.isNotEmpty) {
                 att['clazz'] = clazz;
               }

               if (isActive) {
                 _currentAttendances.add(att);
               } else {
                 _completedAttendances.add(att);
               }
            }
            _attendances = allAttendances;

            // Auto-select the most recent course for both tabs
            if (_currentAttendances.isNotEmpty) {
               final mostRecentCurrent = _currentAttendances.first;
               final clazz = mostRecentCurrent['clazz'] ?? {};
               var unwrappedClazz = clazz;
               if (clazz['clazz'] is Map) {
                 unwrappedClazz = clazz['clazz'];
               }
               final classId = unwrappedClazz['id'] ?? unwrappedClazz['classId'];
               
               if (classId != null) {
                 _selectedAttendanceClassId = classId;
               } else if (_currentCourses.isNotEmpty) {
                 // Fallback to first available current course
                 final available = _getAvailableCurrentClassesForFilter();
                 if (available.isNotEmpty) {
                   _selectedAttendanceClassId = available.first['id'];
                 }
               }
            } else if (_completedAttendances.isNotEmpty) {
               // If no current attendances, select from completed
               final mostRecentCompleted = _completedAttendances.first;
               final clazz = mostRecentCompleted['clazz'] ?? {};
               var unwrappedClazz = clazz;
               if (clazz['clazz'] is Map) {
                 unwrappedClazz = clazz['clazz'];
               }
               final classId = unwrappedClazz['id'] ?? unwrappedClazz['classId'];
               
               if (classId != null) {
                 _selectedAttendanceClassId = classId;
               } else if (_completedCourses.isNotEmpty) {
                 // Fallback to first available completed course
                 final available = _getAvailableClassesForFilter();
                 if (available.isNotEmpty) {
                   _selectedAttendanceClassId = available.first['id'];
                 }
               }
            }
            
            // Update student name if available in detail
            final detailName = data['user']?['fullName'] ?? data['fullName'] ?? data['name'];
            if (detailName != null && _selectedChild != null) {
               _selectedChild!['fullName'] = detailName;
               final index = _children.indexWhere((c) => (c['studentId'] ?? c['id']) == studentId);
               if (index != -1) {
                 _children[index]['fullName'] = detailName;
                 if (_children[index]['user'] == null) {
                   _children[index]['user'] = {'fullName': detailName};
                 } else {
                   _children[index]['user']['fullName'] = detailName;
                 }
               }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading student data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Helper to get available classes for filter dropdown
  List<Map<String, dynamic>> _getAvailableClassesForFilter() {
    final Map<int, String> classes = {};
    for (var item in _completedCourses) {
      var clazz = item['clazz'] ?? {};
      // Unwrap studentClass wrapper if present
      if (clazz['clazz'] is Map) {
        clazz = clazz['clazz'];
      }
      
      final classId = clazz['id'] ?? clazz['classId'];
      
      if (classId != null) {
        final subjectName = clazz['name'] ?? clazz['subjectName'] ?? clazz['code'] ?? item['subjectName'] ?? 'Môn học';
            
        final semester = clazz['semester'];
        final semesterName = semester is Map ? semester['name'] : '';
        
        String displayName = subjectName;
        if (semesterName != null && semesterName.toString().isNotEmpty) {
          displayName += ' - $semesterName';
        }
        
        classes[classId] = displayName;
      }
    }
    return classes.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  /// Helper to get available current classes for filter dropdown
  List<Map<String, dynamic>> _getAvailableCurrentClassesForFilter() {
    final Map<int, String> classes = {};
    for (var item in _currentCourses) {
      var clazz = item['clazz'] ?? {};
      // Unwrap studentClass wrapper if present
      if (clazz['clazz'] is Map) {
        clazz = clazz['clazz'];
      }
      
      final classId = clazz['id'] ?? clazz['classId'];
      
      if (classId != null) {
        final subjectName = clazz['name'] ?? clazz['subjectName'] ?? clazz['code'] ?? item['subjectName'] ?? 'Môn học';
            
        final semester = clazz['semester'];
        final semesterName = semester is Map ? semester['name'] : '';
        
        String displayName = subjectName;
        if (semesterName != null && semesterName.toString().isNotEmpty) {
          displayName += ' - $semesterName';
        }
        
        classes[classId] = displayName;
      }
    }
    return classes.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  /// Widget hiển thị danh sách điểm danh.
  Widget _buildAttendanceList() {
    final filteredCurrentAttendances = _selectedAttendanceClassId == null
        ? _currentAttendances
        : _currentAttendances.where((att) {
            var clazz = att['clazz'] ?? {};
            if (clazz['clazz'] is Map) {
              clazz = clazz['clazz'];
            }
            final classId = clazz['id'] ?? clazz['classId'];
            return classId == _selectedAttendanceClassId;
          }).toList();
    
    final filteredCompletedAttendances = _selectedAttendanceClassId == null
        ? _completedAttendances
        : _completedAttendances.where((att) {
            var clazz = att['clazz'] ?? {};
            if (clazz['clazz'] is Map) {
              clazz = clazz['clazz'];
            }
            final classId = clazz['id'] ?? clazz['classId'];
            return classId == _selectedAttendanceClassId;
          }).toList();

    final displayList = _attendanceTabIndex == 0 ? filteredCurrentAttendances : filteredCompletedAttendances;

    final availableClasses = (_attendanceTabIndex == 0 
            ? _getAvailableCurrentClassesForFilter() 
            : _getAvailableClassesForFilter()).toSet().toList();

    // Validate _selectedAttendanceClassId
    if (_selectedAttendanceClassId != null && 
        !availableClasses.any((cls) => cls['id'] == _selectedAttendanceClassId)) {
      _selectedAttendanceClassId = availableClasses.isNotEmpty ? availableClasses.first['id'] : null;
    }

    return Column(
      children: [
        // Toggle Buttons
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _attendanceTabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _attendanceTabIndex == 0 ? Colors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      'Đang học',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _attendanceTabIndex == 0 ? Colors.white : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _attendanceTabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _attendanceTabIndex == 1 ? Colors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      'Đã học',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _attendanceTabIndex == 1 ? Colors.white : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Class Filter (for both "Đang học" and "Đã học")
        if (availableClasses.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Lọc theo khoá học:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isDense: true,
                        value: _selectedAttendanceClassId,
                        items: availableClasses.map((cls) {
                          return DropdownMenuItem<int>(
                            value: cls['id'],
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                cls['name'], 
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedAttendanceClassId = val;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        _buildAttendanceSummary(displayList),

        Expanded(
          child: displayList.isEmpty
              ? Center(child: Text(_attendanceTabIndex == 0 ? 'Chưa có dữ liệu điểm danh' : 'Không có dữ liệu cũ'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    final date = item['attendanceDate'] ?? 'N/A';
                    final rawStatus = (item['status'] ?? 'UNKNOWN').toString().toUpperCase();
                    final reason = item['permissionReason'];
                    
                    // Course Name
                    var clazz = item['clazz'] ?? {};
                    if (clazz['clazz'] is Map) {
                      clazz = clazz['clazz'];
                    }
                    
                    final subjectName = clazz['name'] ?? clazz['subjectName'] ?? clazz['code'] ?? item['subjectName'] ?? 'Điểm danh';
                    
                    // Also try to find subject name in root if not in clazz
                    // (Though usually we rely on clazz)

                    final isPresent = rawStatus == 'PRESENT' || rawStatus == 'CÓ MẶT';
                    final isAbsent = rawStatus == 'ABSENT' || rawStatus == 'VẮNG' || rawStatus == 'VẮNG MẶT';
                    final isLate = rawStatus == 'LATE' || rawStatus == 'MUỘN';
                    
                    // Determine display status and color
                    String displayStatus = 'Vắng mặt';
                    Color statusColor = Colors.red;
                    IconData statusIcon = Icons.close_rounded;

                    if (isPresent) {
                      displayStatus = 'Có mặt';
                      statusColor = Colors.green;
                      statusIcon = Icons.check_rounded;
                    } else if (isLate) {
                      displayStatus = 'Đi muộn';
                      statusColor = Colors.orange;
                      statusIcon = Icons.access_time_rounded;
                    } else if (isAbsent) {
                      displayStatus = 'Vắng mặt';
                      statusColor = Colors.red;
                      statusIcon = Icons.close_rounded;
                    } else {
                       displayStatus = rawStatus; // Fallback
                       statusColor = Colors.grey;
                       statusIcon = Icons.help_outline;
                    }
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border(
                          left: BorderSide(
                            color: statusColor,
                            width: 4,
                          ),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            statusIcon,
                            color: statusColor,
                            size: 20,
                          ),
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subjectName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ngày: $date',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              displayStatus,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (!isPresent && reason != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Lý do: $reason',
                                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 13),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Widget hiển thị tổng quan điểm danh.
  Widget _buildAttendanceSummary(List<Map<String, dynamic>> list) {
    int total = list.length;
    int absent = list.where((a) {
      final s = (a['status'] ?? '').toString().toUpperCase();
      return s == 'ABSENT' || s == 'VẮNG' || s == 'VẮNG MẶT';
    }).length;
    int late = list.where((a) {
      final s = (a['status'] ?? '').toString().toUpperCase();
      return s == 'LATE' || s == 'MUỘN';
    }).length;
    int present = list.where((a) {
      final s = (a['status'] ?? '').toString().toUpperCase();
      return s == 'PRESENT' || s == 'CÓ MẶT';
    }).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Adjusted margin
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Tổng số', '$total', Colors.blue),
          _buildStatItem('Có mặt', '$present', Colors.green),
          _buildStatItem('Vắng', '$absent', Colors.red),
          _buildStatItem('Muộn', '$late', Colors.orange),
        ],
      ),
    );
  }

  /// Widget hiển thị một mục thống kê điểm danh.
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  /// Widget hiển thị danh sách thành tích.
  Widget _buildAchievementList() {
    if (_achievements.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu thành tích'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _achievements.length,
      itemBuilder: (context, index) {
        final item = _achievements[index];
        final title = item['title'] ?? item['name'] ?? 'Thành tích';
        final description = item['description'] ?? '';
        final date = item['date'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: const Border(
              left: BorderSide(color: Colors.amber, width: 4),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.grey[700])),
                ],
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
