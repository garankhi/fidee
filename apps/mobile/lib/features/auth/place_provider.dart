import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'place_provider.g.dart';

class Place {
  final String? id;
  final String? name;
  final String? category;
  final String? address;
  final double? lat;
  final double? lng;
  final String? openTime;
  final String? closeTime;
  final int? priceMin;
  final int? priceMax;
  final String? description;
  final int checkinCount;

  const Place({
    this.id,
    this.name,
    this.category,
    this.address,
    this.lat,
    this.lng,
    this.openTime,
    this.closeTime,
    this.priceMin,
    this.priceMax,
    this.description,
    this.checkinCount = 0,
  });

  Place copyWith({
    String? id,
    String? name,
    String? category,
    String? address,
    double? lat,
    double? lng,
    String? openTime,
    String? closeTime,
    int? priceMin,
    int? priceMax,
    String? description,
    int? checkinCount,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      description: description ?? this.description,
      checkinCount: checkinCount ?? this.checkinCount,
    );
  }
}

@riverpod
class PlaceController extends _$PlaceController {
  @override
  Place build() => const Place();

  Future<void> fetchPlaceDetail(String placeId) async {
    const baseUrl = 'https://api.fidee.site/places';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$placeId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonResult = json.decode(response.body) as Map<String, dynamic>;
        final data = jsonResult['data'] as Map<String, dynamic>? ?? {};

        final coordinates = data['coordinates'] as Map<String, dynamic>? ?? {};
        final double parsedLat = double.tryParse(coordinates['lat']?.toString() ?? '') ?? 0.0;
        final double parsedLng = double.tryParse(coordinates['lng']?.toString() ?? '') ?? 0.0;

        state = Place(
          id: data['id'] as String?,
          name: data['name'] as String?,
          category: data['category'] as String?,
          address: data['address'] as String?,
          lat: parsedLat,
          lng: parsedLng,
          openTime: data['open_time'] as String?,
          closeTime: data['close_time'] as String?,
          priceMin: int.tryParse(data['price_min']?.toString() ?? ''),
          priceMax: int.tryParse(data['price_max']?.toString() ?? ''),
          description: data['description'] as String?,
          checkinCount: int.tryParse(data['checkin_count']?.toString() ?? '') ?? 0,
        );
      }
    } catch (e) {
      state = const Place();
    }
  }

  void clear() => state = const Place();
}