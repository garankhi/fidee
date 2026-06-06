import 'place_details.dart';

class PlaceDetailsResponse {
  final String status;
  final PlaceDetails data;

  const PlaceDetailsResponse({required this.status, required this.data});

  factory PlaceDetailsResponse.fromJson(Map<String, dynamic> json) {
    return PlaceDetailsResponse(
      status: json['status'] as String? ?? 'error',
      data: PlaceDetails.fromJson(json['data'] as Map<String, dynamic>? ?? {}),
    );
  }
}