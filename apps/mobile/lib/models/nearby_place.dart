/// Data models for the GET /places/nearby API contract.
library;

class NearbyPlaceCoordinates {
  final double lat;
  final double lng;

  const NearbyPlaceCoordinates({required this.lat, required this.lng});

  factory NearbyPlaceCoordinates.fromJson(Map<String, dynamic> json) {
    return NearbyPlaceCoordinates(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class NearbyPlaceActions {
  final String primary;

  const NearbyPlaceActions({required this.primary});

  factory NearbyPlaceActions.fromJson(Map<String, dynamic> json) {
    return NearbyPlaceActions(primary: json['primary'] as String);
  }
}

class NearbyPlace {
  final String id;
  final String? placeId;
  final String source;
  final String displayName;
  final String address;
  final String category;
  final int distanceMeters;
  final String confidence;
  final NearbyPlaceCoordinates coordinates;
  final NearbyPlaceActions actions;

  const NearbyPlace({
    required this.id,
    this.placeId,
    required this.source,
    required this.displayName,
    required this.address,
    required this.category,
    required this.distanceMeters,
    required this.confidence,
    required this.coordinates,
    required this.actions,
  });

  bool get isCustomFallback => source == 'custom';
  bool get isGoong => source == 'goong_places';

  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    return NearbyPlace(
      id: json['id'] as String,
      placeId: json['place_id'] as String?,
      source: json['source'] as String,
      displayName: json['display_name'] as String,
      address: json['address'] as String,
      category: json['category'] as String,
      distanceMeters: json['distance_meters'] as int,
      confidence: json['confidence'] as String,
      coordinates: NearbyPlaceCoordinates.fromJson(
        json['coordinates'] as Map<String, dynamic>,
      ),
      actions: NearbyPlaceActions.fromJson(
        json['actions'] as Map<String, dynamic>,
      ),
    );
  }
}

class NearbyMetadata {
  final String source;
  final bool hasGoongFallback;
  final int totalResults;

  const NearbyMetadata({
    required this.source,
    required this.hasGoongFallback,
    required this.totalResults,
  });

  factory NearbyMetadata.fromJson(Map<String, dynamic> json) {
    return NearbyMetadata(
      source: json['source'] as String,
      hasGoongFallback: json['has_goong_fallback'] as bool,
      totalResults: json['total_results'] as int,
    );
  }
}

class NearbyResponse {
  final String status;
  final NearbyMetadata metadata;
  final List<NearbyPlace> data;

  const NearbyResponse({
    required this.status,
    required this.metadata,
    required this.data,
  });

  factory NearbyResponse.fromJson(Map<String, dynamic> json) {
    return NearbyResponse(
      status: json['status'] as String,
      metadata: NearbyMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>,
      ),
      data: (json['data'] as List)
          .map((e) => NearbyPlace.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
