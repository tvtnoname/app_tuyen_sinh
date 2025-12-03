import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class NotificationService {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/notifications.json');
  }

  // Đọc thông báo từ file có thể ghi

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final file = await _localFile;

      // Nếu file chưa tồn tại, sao chép từ assets

      if (!await file.exists()) {
        final String jsonString = await rootBundle.loadString('assets/data/notifications.json');
        await file.writeAsString(jsonString);
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }
      
      final List<dynamic> decoded = json.decode(contents);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error reading notifications: $e');
      return [];
    }
  }

  // Lưu (ghi đè) toàn bộ danh sách thông báo

  Future<File> saveNotifications(List<Map<String, dynamic>> notifications) async {
    final file = await _localFile;
    final String encoded = json.encode(notifications);
    return file.writeAsString(encoded);
  }
}
