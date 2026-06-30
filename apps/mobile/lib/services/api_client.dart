import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiUnauthorizedException extends ApiException {
  const ApiUnauthorizedException() : super('Unauthorized', statusCode: 401);
}

class ApiClient {
  final AuthService _authService;
  final http.Client _client;
  final String _baseUrl;

  ApiClient(
    this._authService, {
    http.Client? client,
    String baseUrl = Config.apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String> queryParameters = const <String, String>{},
    bool authenticated = true,
  }) async {
    final response = await _client.get(
      _uri(path, queryParameters: queryParameters),
      headers: await _headers(authenticated: authenticated),
    );
    return _decodeJsonResponse(response);
  }

  Uri _uri(
    String path, {
    Map<String, String> queryParameters = const <String, String>{},
  }) {
    return Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Future<Map<String, String>> _headers({required bool authenticated}) async {
    if (!authenticated) return const <String, String>{};

    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const ApiUnauthorizedException();
    }
    return <String, String>{'Authorization': token};
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Request failed.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Invalid response.');
  }
}
