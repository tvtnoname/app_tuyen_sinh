import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentScreen extends StatelessWidget {
  final Map<String, dynamic> courseDetails;
  final String selectedDuration;
  final double amount;
  final String paymentMethod;

  const PaymentScreen({
    super.key,
    required this.courseDetails,
    required this.selectedDuration,
    required this.amount,
    required this.paymentMethod,
  });

  /// Định dạng số tiền sang kiểu tiền tệ Việt Nam (VNĐ).
  String _formatPrice(double price) {
    final format = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
    return format.format(price);
  }

  /// Hiển thị bảng thanh toán QR.
  void _showQrPaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => QrPaymentSheet(amount: amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận thanh toán'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chi tiết khóa học', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.book_outlined, "Khóa học", courseDetails['title'] ?? 'N/A'),
                    _buildDetailRow(Icons.location_on_outlined, "Chi nhánh", courseDetails['branch'] ?? 'N/A'),
                    _buildDetailRow(Icons.calendar_today_outlined, "Lịch học", courseDetails['days'] ?? 'N/A'),
                    _buildDetailRow(Icons.access_time_outlined, "Khung giờ", courseDetails['time'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chi tiết thanh toán', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.timelapse_outlined, "Nhu cầu", selectedDuration),
                    _buildDetailRow(Icons.payment_outlined, "Hình thức", paymentMethod),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("SỐ TIỀN THANH TOÁN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      trailing: Text(_formatPrice(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.green)),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showQrPaymentSheet(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Thanh toán'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị một dòng thông tin chi tiết.
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontSize: 16)),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// --- Bảng thanh toán QR ---
class QrPaymentSheet extends StatefulWidget {
  final double amount;
  const QrPaymentSheet({super.key, required this.amount});

  @override
  State<QrPaymentSheet> createState() => _QrPaymentSheetState();
}

class _QrPaymentSheetState extends State<QrPaymentSheet> {
  late Timer _timer;
  int _start = 600; // 10 phút

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  /// Bắt đầu đếm ngược thời gian giao dịch.
  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        if (mounted) {
          setState(() {
            _start--;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Định dạng thời gian đếm ngược (mm:ss).
  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor().toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  /// Định dạng giá tiền.
  String _formatPrice(double price) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ').format(price);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quét mã để thanh toán', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Image.asset('assets/images/qr_code.jpg', height: 200, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) {
            return const Center(child: Text('Không tìm thấy ảnh QR.', style: TextStyle(color: Colors.red)));
          }),
          const SizedBox(height: 16),
          Text('Số tiền', style: TextStyle(fontSize: 16, color: Colors.grey[700]), textAlign: TextAlign.center),
          Text(_formatPrice(widget.amount), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text('Giao dịch kết thúc sau: ', style: TextStyle(color: Colors.red.shade800)),
                Text(_formatTime(_start), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chức năng đang được phát triển!')));
            },
            icon: const Icon(Icons.download_for_offline_outlined),
            label: const Text('Lưu mã QR'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
