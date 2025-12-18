import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../screens/common/course_detail_screen.dart';

class CourseCard extends StatelessWidget {
  final Course course;

  const CourseCard({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260, // Giảm chiều rộng để user thấy thẻ tiếp theo
      height: 250, // Tăng thêm chiều cao để tránh overflow
      margin: const EdgeInsets.only(right: 16, bottom: 8), // Thêm margin bottom cho shadow
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withOpacity(0.15),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
             Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseDetailScreen(course: course),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        course.name,
                        style: const TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(course.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        course.status,
                        style: TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(course.status),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF1F2F6), height: 1),
                const SizedBox(height: 16),

                // Body: Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.calendar_today_rounded, course.schedule, const Color(0xFF4A90E2)),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.location_on_outlined, course.location, const Color(0xFFFF7675)),
                    ],
                  ),
                ),

                // Footer: Price and CTA hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatPrice(course.price),
                      style: const TextStyle(
                        fontFamily: 'Times New Roman',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0984E3),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F2F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF636E72)),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(String price) {
    if (price.isEmpty) return price;

    try {
      // Xử lý trường hợp "1850000.0" hoặc "1850000 VNĐ"
      // 1. Loại bỏ các ký tự KHÔNG phải là số hoặc dấu chấm (.)
      String cleanPrice = price.replaceAll(RegExp(r'[^0-9.]'), '');
      
      double value = double.parse(cleanPrice);
      
      // Format manual: chuyển về int để bỏ phần thập phân .0
      String formatted = value.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
          (Match m) => '${m[1]}.'
      );
      return '$formatted VNĐ';
    } catch (e) {
      // Nếu parse lỗi (VD: chuỗi không đúng định dạng), trả về nguyên gốc
      return price;
    }
  }

  Widget _buildInfoRow(IconData icon, String text, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
           padding: const EdgeInsets.all(6),
           decoration: BoxDecoration(
             color: iconColor.withOpacity(0.1),
             shape: BoxShape.circle,
           ),
           child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 14,
                color: Color(0xFF636E72),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    if (status.toLowerCase().contains("mở") || status.toLowerCase().contains("đang")) {
      return const Color(0xFF00B894); // Green
    } else if (status.toLowerCase().contains("full") || status.toLowerCase().contains("hết")) {
      return const Color(0xFFFF7675); // Red
    }
    return const Color(0xFF0984E3); // Blue
  }
}
