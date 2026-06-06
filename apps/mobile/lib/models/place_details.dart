library;

class Coordinates {
  final double lat;
  final double lng;

  const Coordinates({required this.lat, required this.lng});

  factory Coordinates.fromJson(Map<String, dynamic> json) {
    return Coordinates(
      lat: double.tryParse(json['lat']?.toString() ?? '0.0') ?? 0.0,
      lng: double.tryParse(json['lng']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

class PlaceDetails {
  final String id;
  final String name;
  final String category;
  final String? address;
  final Coordinates coordinates;
  final String? openTime;
  final String? closeTime;
  final int? priceMin;
  final int? priceMax;
  final String? description;
  final String? visibility;
  final String? status;
  final bool isFeatured;
  final bool isVerified;
  final int checkinCount;
  final Map<String, dynamic>? metadata;

  const PlaceDetails({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.coordinates,
    this.openTime,
    this.closeTime,
    this.priceMin,
    this.priceMax,
    this.description,
    this.visibility,
    this.status,
    this.isFeatured = false,
    this.isVerified = false,
    this.checkinCount = 0,
    this.metadata,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    return PlaceDetails(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Chưa cập nhật tên',
      category: json['category'] as String? ?? 'cafe',
      address: json['address'] as String?,
      coordinates: Coordinates.fromJson(json['coordinates'] as Map<String, dynamic>? ?? {}),
      openTime: json['open_time'] as String?,
      closeTime: json['close_time'] as String?,
      priceMin: int.tryParse(json['price_min']?.toString() ?? ''),
      priceMax: int.tryParse(json['price_max']?.toString() ?? ''),
      description: json['description'] as String?,
      visibility: json['visibility'] as String?,
      status: json['status'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      checkinCount: int.tryParse(json['checkin_count']?.toString() ?? '') ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}