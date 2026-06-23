import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/suggestion.dart';

class GoongAutocompleteService {
  static const String _autocompleteUrl =
      'https://rsapi.goong.io/Place/AutoComplete';
  static const String _placeDetailUrl = 'https://rsapi.goong.io/Place/Detail';
  static const Duration _requestTimeout = Duration(seconds: 5);

  final String apiKey;
  final http.Client _client;

  GoongAutocompleteService({
    String? apiKey,
    http.Client? client,
  }) : apiKey = apiKey ?? Config.goongApiKey,
       _client = client ?? http.Client();

  Future<List<Suggestion>> fetchSuggestions({
    required String query,
    required double latitude,
    required double longitude,
  }) async {
    if (apiKey.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(_autocompleteUrl).replace(
        queryParameters: {
          'input': query,
          'location': '$latitude,$longitude',
          'api_key': apiKey,
        },
      );
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return [];

      final predictions = decoded['predictions'];
      if (predictions is! List) return [];

      return predictions
          .map(_parseSuggestion)
          .whereType<Suggestion>()
          .toList(growable: false);
    } on Object catch (error) {
      debugPrint('Goong autocomplete failed: $error');
      return [];
    }
  }

  Future<SuggestionCoordinates?> fetchPlaceCoordinates({
    required String placeId,
  }) async {
    if (apiKey.trim().isEmpty || placeId.trim().isEmpty) return null;

    try {
      final uri = Uri.parse(_placeDetailUrl).replace(
        queryParameters: {
          'place_id': placeId,
          'api_key': apiKey,
        },
      );
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      return _parseCoordinates(decoded);
    } on Object catch (error) {
      debugPrint('Goong place detail failed: $error');
      return null;
    }
  }

  Suggestion? _parseSuggestion(Object? prediction) {
    if (prediction is! Map<String, dynamic>) return null;

    final placeId = _nonEmptyString(prediction['place_id']);
    final structuredFormatting = prediction['structured_formatting'];
    if (structuredFormatting is! Map<String, dynamic>) return null;

    final mainText = _nonEmptyString(structuredFormatting['main_text']);
    final secondaryText = _nonEmptyString(
      structuredFormatting['secondary_text'],
    );

    if (placeId == null || mainText == null || secondaryText == null) {
      return null;
    }

    return Suggestion(
      placeId: placeId,
      mainText: mainText,
      secondaryText: secondaryText,
    );
  }

  SuggestionCoordinates? _parseCoordinates(Map<String, dynamic> decoded) {
    final result = decoded['result'];
    if (result is! Map<String, dynamic>) return null;

    final geometry = result['geometry'];
    if (geometry is! Map<String, dynamic>) return null;

    final location = geometry['location'];
    if (location is! Map<String, dynamic>) return null;

    final lat = (location['lat'] as num?)?.toDouble();
    final lng = (location['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return SuggestionCoordinates(lat: lat, lng: lng);
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String) return null;

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
