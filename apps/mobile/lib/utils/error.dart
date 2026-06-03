import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ErrorDialogs {
  static void showMissingGpsError(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Không tìm thấy vị trí',
          style: TextStyle(
            color: Color(0xFFEF484F),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Bức ảnh này không chứa dữ liệu vị trí (GPS). Vui lòng chọn một bức ảnh khác được chụp bằng camera gốc của máy với tính năng gắn thẻ vị trí đã được bật.',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'SF Pro',
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF484F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Đã hiểu',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showPermissionDeniedError(
    BuildContext context,
    String permissionType,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Thiếu quyền truy cập',
          style: TextStyle(
            color: Color(0xFFEF484F),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'FIDEE cần truy cập $permissionType để thực hiện chức năng này. Vui lòng cấp quyền trong Cài đặt hệ thống.',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'SF Pro',
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Colors.white54, fontFamily: 'SF Pro'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF484F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Mở Cài đặt',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showBadAccuracyError(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gps_fixed, color: Colors.amber),
            SizedBox(width: 10),
            Text(
              'Tín hiệu GPS yếu',
              style: TextStyle(
                color: Colors.amber,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Tọa độ vị trí hiện tại của bạn không đủ chính xác để check-in. Vui lòng thử lại.',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'SF Pro',
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Đã hiểu',
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showUploadError(BuildContext context, VoidCallback onRetry, {String? errorMessage}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Tải lên thất bại',
          style: TextStyle(
            color: Color(0xFFEF484F),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          errorMessage ?? 'Đã có lỗi xảy ra trong quá trình tải ảnh lên. Vui lòng kiểm tra kết nối mạng và thử lại.',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'SF Pro',
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Colors.white54, fontFamily: 'SF Pro'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry(); // Gọi lại hàm truyền vào
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF484F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Thử lại',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
