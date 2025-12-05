import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // URL của Chatbot trên Hugging Face Spaces
  final String apiUrl = "https://tvtnoname01-chatbot-tuyen-sinh.hf.space/api/chat";

  /// Gửi câu hỏi đến Chatbot và nhận câu trả lời
  Future<String> sendMessage(String question) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'question': question}),
      );

      if (response.statusCode == 200) {
        // Giải mã phản hồi UTF-8 để hiển thị đúng tiếng Việt
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        return data['answer'] ?? "Xin lỗi, tôi không hiểu câu hỏi.";
      } else {
        throw Exception('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Không thể kết nối đến Chatbot: $e');
    }
  }
}
