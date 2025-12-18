class Course {
  final String id;
  final String name;
  final String schedule;
  final String location;
  final String price;
  final String status;
  final String endDate;

  Course({
    required this.id,
    required this.name,
    required this.schedule,
    required this.location,
    required this.price,
    required this.status,
    required this.endDate,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    String schedule = json['schedule'] ?? '';
    return Course(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      schedule: _formatSchedule(schedule),
      location: json['location'] ?? '',
      price: json['price'] ?? '',
      status: json['status'] ?? '',
      endDate: json['endDate'] ?? '',
    );
  }

  static String _formatSchedule(String rawSchedule) {
    if (rawSchedule.isEmpty) return rawSchedule;

    // 1. Fix lỗi hiển thị: Backend trả về "Thứ 1" (không hợp lệ), sửa thành "Thứ 5"
    String schedule = rawSchedule.replaceAll(RegExp(r'Thứ 1(?!\d)'), 'Thứ 5');

    // 2. Gom nhóm các ngày có cùng ca học
    // VD: "Thứ 3 - Ca sáng..., Thứ 5 - Ca sáng..." -> "Thứ 3, Thứ 5 - Ca sáng..."
    try {
      List<String> parts = schedule.split(',').map((e) => e.trim()).toList();
      Map<String, List<String>> grouped = {};
      List<String> order = [];

      for (var part in parts) {
        var match = RegExp(r'^(Thứ \d+)\s*-\s*(.*)$').firstMatch(part);
        if (match != null) {
          String day = match.group(1)!;
          String suffix = match.group(2)!;
          
          if (!grouped.containsKey(suffix)) {
            grouped[suffix] = [];
            order.add(suffix);
          }
          grouped[suffix]!.add(day);
        } else {
           // Trường hợp không đúng định dạng "Thứ X - ..." thì giữ nguyên
           if (!grouped.containsKey('other')) {
            grouped['other'] = [];
            order.add('other');
          }
          grouped['other']!.add(part);
        }
      }

      List<String> resultParts = [];
      for (var key in order) {
        if (key == 'other') {
          resultParts.addAll(grouped[key]!);
        } else {
          resultParts.add("${grouped[key]!.join(', ')} - $key");
        }
      }
      return resultParts.join(', ');
    } catch (e) {
      return schedule; // Fallback nếu có lỗi parse
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'schedule': schedule,
      'location': location,
      'price': price,
      'status': status,
      'endDate': endDate,
    };
  }
}
