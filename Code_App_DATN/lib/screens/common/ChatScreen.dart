import 'dart:convert';
import 'dart:math';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/common/chat_service.dart';
import '../../services/auth/auth_service.dart';
import '../../models/course_model.dart';
import '../../widgets/course_card.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = false;
  String _displayUserId = "Loading...";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'bot',
      'text': 'Xin chào! Tôi là trợ lý ảo tuyển sinh. Bạn cần giúp gì không?',
      'options': <String>[],
      'courses': <Course>[],
    });

    _initData();
  }

  Future<void> _initData() async {
    // 1. Phải đồng bộ ID trước
    await _syncUserIdFromAuth(); 
    // 2. Sau đó mới load history với ID đúng
    if (mounted) {
      _loadHistory(); 
    }
  }

  /// Đồng bộ user_id từ tài khoản đã đăng nhập (nếu có)
  Future<void> _syncUserIdFromAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null && token.isNotEmpty) {
        // User đã đăng nhập, lấy profile để có user_id
        final user = await _authService.fetchProfile();
        if (user != null && user.id != null) {
          // Lưu ID thật vào chat_user_id
          await prefs.setString('chat_user_id', user.id.toString());
          print('✅ Đã đồng bộ chat_user_id = ${user.id}');
        }
      }
    } catch (e) {
      print('Lỗi khi đồng bộ user_id: $e');
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final history = await _chatService.getChatHistory();
    // Load ID real-time
    final userId = await _chatService.getUserId();

    if (mounted) {
      setState(() {
        _history = history;
        _displayUserId = userId; // Cập nhật ID hiển thị
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _loadSession(String sessionId) async {
    Navigator.pop(context); // Close drawer
    setState(() => _isLoading = true);
    
    // Set current session ID to continue chatting
    _chatService.setSessionId(sessionId);
    
    final details = await _chatService.getSessionDetails(sessionId);
    
    if (mounted) {
      setState(() {
        _messages.clear();
        for (var msg in details) {
          _messages.add({
            'role': msg['role'] == 'assistant' ? 'bot' : 'user',
            'text': msg['content'] ?? '',
            'options': _parseOptions(msg['options'] ?? msg['Options']),
            'courses': msg['courses'] != null 
                ? (msg['courses'] as List).map((x) => Course.fromJson(x)).toList() 
                : <Course>[],
            'isLocked': true,
            'selectedOption': null,
          });
        }
        _isLoading = false;
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      });
    }
  }

  List<String> _parseOptions(dynamic options) {
    if (options == null) return <String>[];
    
    // 1. Direct List
    if (options is List) {
      return options.map((e) => e.toString()).toList();
    }
    
    // 2. String Parsing
    if (options is String) {
      // Cleanup: sometimes strings are wrapped in extra quotes ""[...]""
      String clean = options.trim();
      if (clean.startsWith('"') && clean.endsWith('"')) {
        clean = clean.substring(1, clean.length - 1).replaceAll(r'\"', '"');
      }

      try {
        final decoded = jsonDecode(clean);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
        // Handle double-encoded case: "[\"a\",\"b\"]" -> decoded as String -> decode again
        if (decoded is String) {
          final decoded2 = jsonDecode(decoded);
          if (decoded2 is List) {
            return decoded2.map((e) => e.toString()).toList();
          }
        }
      } catch (e) {
        // Fallback: manual split if it looks like a simple list [a, b]
        if (clean.startsWith('[') && clean.endsWith(']')) {
           final content = clean.substring(1, clean.length - 1);
           if (content.isNotEmpty) {
             return content.split(',').map((e) => e.trim().replaceAll('"', '')).toList();
           }
        }
      }
    }
    
    return <String>[];
  }



  void _resetChat() {
    _chatService.resetSession();
    setState(() {
      _messages.clear();
      _messages.add({
        'role': 'bot',
        'text': 'Xin chào! Tôi là trợ lý ảo tuyển sinh. Bạn cần giúp gì không?',
        'options': <String>[],
        'courses': <Course>[],
      });
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
      // Add placeholder for bot response
      _messages.add({
        'role': 'bot',
        'text': '', // Start empty
        'options': <String>[],
        'courses': <Course>[],
      });
    });
    
    _scrollToBottom();

    try {
      final stream = _chatService.streamSendMessage(text);
      bool historyUpdated = false;
      
      await for (final data in stream) {
        if (!mounted) break;
        
        // MỚI: Nếu server trả về session_id (tức là đã tạo session),
        // và chưa update history lần nào trong lần gửi này -> reload history ngay
        if (!historyUpdated && data['session_id'] != null) {
          _loadHistory(); 
          historyUpdated = true;
        }
        
        setState(() {
          final botMsgIndex = _messages.length - 1;
          final currentText = _messages[botMsgIndex]['text'] as String;
          
          // Append text chunk
          if (data['text_chunk'] != null) {
            _messages[botMsgIndex]['text'] = currentText + data['text_chunk'];
          }
          
          // Update options if present (usually at end)
          if (data['options'] != null) {
             _messages[botMsgIndex]['options'] = List<String>.from(data['options']);
          }
          
          // Update courses if present (usually at end)
           if (data['courses'] != null) {
             _messages[botMsgIndex]['courses'] = (data['courses'] as List)
                .map((x) => Course.fromJson(x))
                .toList();
          }
        });
        _scrollToBottom();
      }
      
      // Fallback: Nếu stream xong mà vẫn chưa update (trường hợp hiếm), update phát cuối
      if (!historyUpdated) {
        _loadHistory();
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
           // If error, append error message to current bot message or new one?
           // Current bot message might be empty or partial.
           // Let's just append error text.
           final botMsgIndex = _messages.length - 1;
           _messages[botMsgIndex]['text'] = (_messages[botMsgIndex]['text'] as String) + "\n(Lỗi kết nối: $e)";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.history_edu, color: Colors.white, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'Lịch sử tư vấn',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID: $_displayUserId',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Chưa có lịch sử tư vấn", style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _loadHistory,
                                child: const Text("Tải lại"),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadHistory,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            itemCount: _history.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          final title = item['title'] ?? 'Cuộc hội thoại ${index + 1}';
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _loadSession(item['session_id']);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDF2F7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF4A90E2), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF2D3748),
                                          fontFamily: 'Times New Roman',
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                                      onSelected: (value) {
                                        if (value == 'rename') {
                                          _showRenameDialog(item['session_id'], title);
                                        } else if (value == 'delete') {
                                          _showDeleteConfirmation(item['session_id']);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(
                                          value: 'rename',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 20, color: Colors.blue),
                                              SizedBox(width: 8),
                                              Text('Đổi tên'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, size: 20, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Xóa', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF5F7FB), // Màu nền nhẹ nhàng hiện đại
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.support_agent_rounded, color: Color(0xFF4A90E2)),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trợ lý tuyển sinh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman')),
                Text('Luôn sẵn sàng hỗ trợ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, fontFamily: 'Times New Roman')),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
            tooltip: 'Chat mới',
            onPressed: _resetChat,
          ),
        ],
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length, // Đã có sẵn placeholder, không cần +1
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _MessageBubble(
                  text: msg['text'] as String,
                  isUser: msg['role'] == 'user',
                  options: msg['options'] as List<String>?,
                  courses: msg['courses'] as List<Course>?,
                  isLocked: msg['isLocked'] as bool? ?? false,
                  selectedOption: msg['selectedOption'] as String?,
                  onOptionSelected: (option) {
                    setState(() {
                      msg['isLocked'] = true;
                      msg['selectedOption'] = option;
                    });
                     // Gửi lựa chọn dưới dạng tin nhắn
                    _controller.text = option;
                    _sendMessage();
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  void _showRenameDialog(String sessionId, String currentTitle) {
    final TextEditingController _renameController = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Đổi tên cuộc hội thoại'),
          content: TextField(
            controller: _renameController,
            decoration: const InputDecoration(hintText: "Nhập tên mới"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                final newTitle = _renameController.text.trim();
                if (newTitle.isNotEmpty) {
                  final success = await _chatService.renameSession(sessionId, newTitle);
                  if (success) {
                    _loadHistory();
                  }
                }
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(String sessionId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa cuộc hội thoại?'),
          content: const Text('Hành động này không thể hoàn tác.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                final success = await _chatService.deleteSession(sessionId);
                if (success) {
                  _loadHistory();
                  // Nếu đang ở trong session bị xóa, reset về chat mới
                  // (Logic này cần check session hiện tại, tạm thời reset nêú muốn an toàn)
                   _resetChat(); 
                }
                Navigator.pop(context);
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  // Disable nếu đang loading (streaming) hoặc tin nhắn cuối bot có option chưa chọn
                  enabled: !_isLoading && !(_messages.isNotEmpty && 
                     _messages.last['role'] == 'bot' && 
                     (_messages.last['options'] as List).isNotEmpty && 
                     !(_messages.last['isLocked'] as bool? ?? false)),
                  style: const TextStyle(fontFamily: 'Times New Roman'),
                  decoration: InputDecoration(
                    hintText: (_messages.isNotEmpty && 
                               _messages.last['role'] == 'bot' && 
                               (_messages.last['options'] as List).isNotEmpty && 
                               !(_messages.last['isLocked'] as bool? ?? false)) 
                        ? 'Vui lòng chọn phương án trên...' 
                        : 'Nhập câu hỏi của bạn...',
                    hintStyle: const TextStyle(color: Colors.grey, fontFamily: 'Times New Roman'),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF4A90E2),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final List<String>? options;
  final List<Course>? courses;
  final Function(String)? onOptionSelected;
  final bool isLocked;
  final String? selectedOption;

  const _MessageBubble({
    required this.text,
    required this.isUser,
    this.options,
    this.courses,
    this.onOptionSelected,
    this.isLocked = false,
    this.selectedOption,
  });

  @override
  Widget build(BuildContext context) {
    // Logic: Nếu bot đang gõ (text empty), hiển thị "..."
    final bool isThinking = !isUser && text.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD), // Light blue bg
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.support_agent_rounded, size: 20, color: Color(0xFF1976D2)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                 Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF4A90E2) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, 2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: isThinking
                      ? const Text("...", style: TextStyle(color: Colors.grey))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text,
                              textAlign: isUser ? TextAlign.right : TextAlign.left,
                              style: TextStyle(
                                color: isUser ? Colors.white : const Color(0xFF2d3436),
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                ),
                


                if (!isUser && options != null && options!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: options!.map((option) {
                      final bool isSelected = option == selectedOption;
                      // Logic màu sắc:
                      // - Nếu chưa lock: Màu trắng, viền xanh (như cũ)
                      // - Nếu lock + được chọn: Màu xanh, chữ trắng
                      // - Nếu lock + không chọn: Màu xám, chữ xám nhạt (hoặc ẩn đi nếu muốn, ở đây ta làm mờ)
                      
                      Color backgroundColor = Colors.white;
                      Color textColor = const Color(0xFF4A90E2);
                      BorderSide side = const BorderSide(color: Color(0xFF4A90E2));

                      if (isLocked) {
                        if (isSelected) {
                          backgroundColor = const Color(0xFF4A90E2);
                          textColor = Colors.white;
                          side = BorderSide.none;
                        } else {
                          // Darker grey for better visibility
                          backgroundColor = Colors.grey.shade300; 
                          textColor = Colors.black54; 
                          side = BorderSide.none;
                        }
                      }

                      return ActionChip(
                        label: Text(
                          option,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: backgroundColor,
                        side: side,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onPressed: isLocked 
                            ? null // Disable nếu đã lock
                            : () {
                                onOptionSelected?.call(option);
                              },
                        disabledColor: isLocked && isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade100,
                      );
                    }).toList(),
                  ),
                ],
                  if (!isUser && courses != null && courses!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 270, // Tăng chiều cao tương ứng với Card (250px + margin)
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: courses!.length,
                        itemBuilder: (context, index) {
                          return CourseCard(course: courses![index]);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFE1E8ED),
              child: Icon(Icons.person_rounded, size: 18, color: Color(0xFF4A90E2)),
            ),
          ],
          if (!isUser) const SizedBox(width: 40), // Spacer for bot messages to prevent full width
          if (isUser) const SizedBox(width: 0), // No spacer needed for user as avatar is there
        ],
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatefulWidget {
  const _TypingIndicatorBubble();

  @override
  State<_TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<_TypingIndicatorBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD), // Light blue bg
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.support_agent_rounded, size: 20, color: Color(0xFF1976D2)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Height for dots
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return FadeTransition(
                  opacity: DelayTween(begin: 0.0, end: 1.0, delay: index * 0.2)
                      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB0B3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class DelayTween extends Tween<double> {
  DelayTween({super.begin, super.end, required this.delay});

  final double delay;

  @override
  double lerp(double t) {
    return super.lerp((t - delay).clamp(0.0, 1.0));
  }
}
