import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/pro_access.dart';
import 'auth_service.dart';

Map<String, dynamic> buildRevenueCatSyncPayload() {
  return <String, dynamic>{};
}

class BillingSyncService {
  final AuthService _authService;
  final http.Client _client;

  BillingSyncService({required AuthService authService, http.Client? client})
    : _authService = authService,
      _client = client ?? http.Client();

  Future<BillingSyncResult> syncRevenueCat() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const BillingSyncException('Phiên đăng nhập đã hết hạn');
    }

    final response = await _client.post(
      Uri.parse('${Config.apiBaseUrl}/billing/revenuecat/sync'),
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
      body: jsonEncode(buildRevenueCatSyncPayload()),
    );

    if (response.statusCode != 200) {
      throw BillingSyncException(
        'Không đồng bộ được gói Pro (HTTP ${response.statusCode})',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected response object');
      }
      return BillingSyncResult.fromJson(decoded);
    } on FormatException {
      throw const BillingSyncException('Phản hồi đồng bộ gói Pro không hợp lệ');
    }
  }
}

class BillingSyncException implements Exception {
  final String message;

  const BillingSyncException(this.message);

  @override
  String toString() => message;
}
