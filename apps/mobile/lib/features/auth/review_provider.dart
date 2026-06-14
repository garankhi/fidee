import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/auth_providers.dart'; // Import auth để lấy token giống dashboard

part 'review_provider.g.dart';

// 1. Quản lý Trạng thái State giống như cấu trúc DashboardState
class ReviewState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? submittedData;
  final bool isSuccess;

  const ReviewState({
    this.isLoading = false,
    this.errorMessage,
    this.submittedData,
    this.isSuccess = false,
  });

  ReviewState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? submittedData,
    bool? isSuccess,
  }) {
    return ReviewState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // Sẽ lấy giá trị mới truyền vào (hoặc null nếu reset)
      submittedData: submittedData ?? this.submittedData,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// 2. Định nghĩa Controller bằng @riverpod kế thừa code-gen
@riverpod
class ReviewController extends _$ReviewController {
  @override
  ReviewState build() {
    // Không tự động fetch gì khi khởi tạo, trả về state rỗng ban đầu
    return const ReviewState();
  }

  /// Hàm xử lý gửi đánh giá lên API POST /reviews bằng cách nhận full payload Map
  Future<bool> submitReview(Map<String, dynamic> payload) async {
    // Bật trạng thái loading và clear error cũ nếu có
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);

    final authService = ref.read(authServiceProvider);
    final token = await authService.getToken();

    try {
      final response = await http.post(
        Uri.parse('https://api.fidee.site/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload), // Encode trực tiếp payload nhận từ UI
      );

      // Log để debug khi dev (có thể comment khi deploy production)
      developer.log('Payload sent: ${jsonEncode(payload)}', name: 'ReviewController');
      developer.log('Response status: ${response.statusCode}', name: 'ReviewController');
      developer.log('Response body: ${response.body}', name: 'ReviewController');

      if (response.statusCode != 200 && response.statusCode != 201) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Gửi đánh giá thất bại (Mã lỗi: ${response.statusCode})',
        );
        return false;
      }

      final jsonResult = jsonDecode(response.body) as Map<String, dynamic>;

      // Tùy theo response format của backend:
      // Nếu backend trả về trực tiếp object hoặc bọc trong 'status' / 'success'
      if (jsonResult['status'] == 'success' || jsonResult['success'] == true || response.statusCode == 201) {
        final rawData = jsonResult['data'] as Map<String, dynamic>? ?? jsonResult;

        state = state.copyWith(
          isLoading: false,
          isSuccess: true,
          submittedData: rawData,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: jsonResult['message'] as String,
        );
        return false;
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to submit review.',
        name: 'ReviewController',
        error: error,
        stackTrace: stackTrace,
      );

      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  /// Reset lại trạng thái cũ sau khi đã hiển thị dialog/popup xong
  void resetState() {
    state = const ReviewState();
  }
}