/// Data models for the GET /places/:id API contract.
library;

class PlaceCoordinates {
  final double lat;
  final double lng;

  const PlaceCoordinates({required this.lat, required this.lng});

  factory PlaceCoordinates.fromJson(Map<String, dynamic> json) {
    return PlaceCoordinates(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class PlaceDetails {
  final String id;
  final String name;
  final String? category;
  final String? address;
  final String? openTime;
  final String? closeTime;
  final int? priceMin;
  final int? priceMax;
  final String? description;
  final Map<String, dynamic>? metadata;
  final String? visibility;
  final String? status;
  final bool? isFeatured;
  final bool? isVerified;
  final int checkinCount;
  final PlaceCoordinates coordinates;

  const PlaceDetails({
    required this.id,
    required this.name,
    this.category,
    this.address,
    this.openTime,
    this.closeTime,
    this.priceMin,
    this.priceMax,
    this.description,
    this.metadata,
    this.visibility,
    this.status,
    this.isFeatured,
    this.isVerified,
    required this.checkinCount,
    required this.coordinates,
  });

  bool get isApproved => status == 'APPROVED';
  bool get isCandidate => status != 'APPROVED' && status != null;

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    return PlaceDetails(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      address: json['address'] as String?,
      openTime: json['open_time'] as String?,
      closeTime: json['close_time'] as String?,
      priceMin: json['price_min'] as int?,
      priceMax: json['price_max'] as int?,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      visibility: json['visibility'] as String?,
      status: json['status'] as String?,
      isFeatured: json['is_featured'] as bool?,
      isVerified: json['is_verified'] as bool?,
      checkinCount: json['checkin_count'] as int,
      coordinates: PlaceCoordinates.fromJson(
        json['coordinates'] as Map<String, dynamic>,
      ),
    );
  }
}

class PlaceDetailsResponse {
  final String status;
  final PlaceDetails data;

  const PlaceDetailsResponse({
    required this.status,
    required this.data,
  });

  factory PlaceDetailsResponse.fromJson(Map<String, dynamic> json) {
    return PlaceDetailsResponse(
      status: json['status'] as String,
      data: PlaceDetails.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}