import 'nearby_place.dart';

class SelectedPlaceTag {
  final String id;
  final String displayName;
  final String address;
  final double lat;
  final double lng;
  final String source;
  final String? placeId;

  const SelectedPlaceTag({
    required this.id,
    required this.displayName,
    required this.address,
    required this.lat,
    required this.lng,
    required this.source,
    this.placeId,
  });

  factory SelectedPlaceTag.fromNearby(NearbyPlace place) {
    return SelectedPlaceTag(
      id: place.id,
      displayName: place.displayName,
      address: place.address,
      lat: place.coordinates.lat,
      lng: place.coordinates.lng,
      source: place.source,
      placeId: place.placeId,
    );
  }
}
