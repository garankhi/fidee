import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

Map<String, dynamic> buildRevenueCatSyncPayload({
  required String appUserId,
  required Set<String> activeEntitlementIds,
  String? productId,
  String? store,
  String? expiresAt,
  Map<String, dynamic>? customerInfo,
}) {
  return {
    'appUserId': appUserId,
    'activeEntitlementIds': activeEntitlementIds.toList()..sort(),
    'productId': ?productId,
    'store': ?store,
    'expiresAt': ?expiresAt,
    'customerInfo': ?customerInfo,
  };
}

class BillingSyncService {
  final AuthService _authService;
  final http.Client _client;

  BillingSyncService({required AuthService authService, http.Client? client})
    : _authService = authService,
      _client = client ?? http.Client();

  Future<void> syncRevenueCat({
    required String appUserId,
    required Set<String> activeEntitlementIds,
    String? productId,
    String? store,
    String? expiresAt,
    Map<String, dynamic>? customerInfo,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const BillingSyncException('Phiên đăng nhập đã hết hạn');
    }

    final payload = buildRevenueCatSyncPayload(
      appUserId: appUserId,
      activeEntitlementIds: activeEntitlementIds,
      productId: productId,
      store: store,
      expiresAt: expiresAt,
      customerInfo: customerInfo,
    );
    if (kDebugMode) {
      debugPrint(
        '[RevenueCat] sync request url=${Config.apiBaseUrl}/billing/revenuecat/sync '
        'payload=$payload tokenPresent=${token.isNotEmpty}',
      );
    }

    final response = await _client.post(
      Uri.parse('${Config.apiBaseUrl}/billing/revenuecat/sync'),
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (kDebugMode) {
      debugPrint(
        '[RevenueCat] sync response status=${response.statusCode} body=${response.body}',
      );
    }

    if (response.statusCode != 200) {
      throw BillingSyncException(
        'Không đồng bộ được gói Pro: HTTP ${response.statusCode} ${response.body}',
      );
    }
  }
}

class BillingSyncException implements Exception {
  final String message;

  const BillingSyncException(this.message);

  @override
  String toString() => message;
}
