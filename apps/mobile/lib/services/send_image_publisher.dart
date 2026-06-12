import '../models/camera_share_audience.dart';
import '../models/selected_place_tag.dart';
import 'checkin_service.dart';
import 'upload_service.dart';

class SendImagePublisher {
  final UploadService uploadService;
  final CheckinService checkinService;

  const SendImagePublisher({
    required this.uploadService,
    required this.checkinService,
  });

  Future<CheckinResult> publish({
    required String imagePath,
    required String source,
    required SelectedPlaceTag selectedPlace,
    required CameraShareAudience audience,
    String? caption,
  }) async {
    final mediaId = await uploadService.upload(
      imagePath: imagePath,
      latitude: selectedPlace.lat,
      longitude: selectedPlace.lng,
      source: source,
    );

    return checkinService.createCheckin(
      placeId: _placeIdForCheckin(selectedPlace),
      candidateId: _candidateIdForCheckin(selectedPlace),
      mediaId: mediaId,
      gpsLat: selectedPlace.lat,
      gpsLng: selectedPlace.lng,
      caption: caption,
      audience: audience,
    );
  }

  String? _placeIdForCheckin(SelectedPlaceTag place) {
    final placeId = place.placeId;
    if (placeId != null && placeId.isNotEmpty) return placeId;
    if (place.source == 'internal') return place.id;
    return null;
  }

  String? _candidateIdForCheckin(SelectedPlaceTag place) {
    final placeId = _placeIdForCheckin(place);
    if (placeId != null && placeId.isNotEmpty) return null;
    return place.id;
  }
}
