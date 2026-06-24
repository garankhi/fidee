import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/custom_address_validation.dart';

class GoongGeocodingService {
  static const String _baseUrl = 'https://rsapi.goong.io/Geocode';
  static const Distance _distance = Distance();

  final String apiKey;
  final http.Client _client;
  final int farDistanceMeters;

  GoongGeocodingService({
    String? apiKey,
    http.Client? client,
    this.farDistanceMeters = 250,
  }) : apiKey = apiKey ?? Config.goongApiKey,
       _client = client ?? http.Client();

  Future<String?> reverseGeocode({required double lat, required double lng}) async {
    if (apiKey.trim().isEmpty) return null;

    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'latlng': '$lat,$lng',
          'api_key': apiKey,
        },
      );
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final result = _firstResult(decoded);
      final formattedAddress = result?['formatted_address'] as String?;
      final trimmed = formattedAddress?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    } catch (error) {
      debugPrint('Goong reverse geocode failed: $error');
      return null;
    }
  }

  Future<CustomAddressValidation?> validateAddressNear({
    required String address,
    required double lat,
    required double lng,
  }) async {
    if (apiKey.trim().isEmpty || address.trim().isEmpty) return null;

    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'address': address.trim(),
          'api_key': apiKey,
        },
      );
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final location = _firstLocation(decoded);
      if (location == null) return null;

      final distanceMeters = _distance.as(
        LengthUnit.Meter,
        LatLng(lat, lng),
        LatLng(location.lat, location.lng),
      ).round();

      return CustomAddressValidation(
        isFarFromCurrentLocation: distanceMeters > farDistanceMeters,
        distanceMeters: distanceMeters,
      );
    } catch (error) {
      debugPrint('Goong address validation failed: $error');
      return null;
    }
  }

  Map<String, dynamic>? _firstResult(Map<String, dynamic> decoded) {
    final results = decoded['results'];
    if (results is! List || results.isEmpty) return null;
    final first = results.first;
    return first is Map<String, dynamic> ? first : null;
  }

  _GoongLocation? _firstLocation(Map<String, dynamic> decoded) {
    final first = _firstResult(decoded);
    final geometry = first?['geometry'];
    if (geometry is! Map<String, dynamic>) return null;
    final location = geometry['location'];
    if (location is! Map<String, dynamic>) return null;

    final lat = (location['lat'] as num?)?.toDouble();
    final lng = (location['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return _GoongLocation(lat: lat, lng: lng);
  }
}

class _GoongLocation {
  final double lat;
  final double lng;

  const _GoongLocation({required this.lat, required this.lng});
}
