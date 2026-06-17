import '../models/camera_share_audience.dart';
import '../models/selected_place_tag.dart';
import 'checkin_service.dart';
import 'upload_service.dart';

String checkinMediaTypeForSource(String source) {
  return source.endsWith('_VIDEO') ? 'VIDEO' : 'IMAGE';
}

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
    int? durationMs,
  }) async {
    final mediaId = await uploadService.upload(
      imagePath: imagePath,
      latitude: selectedPlace.lat,
      longitude: selectedPlace.lng,
      source: source,
      durationMs: durationMs,
    );

    return checkinService.createCheckin(
      placeId: _placeIdForCheckin(selectedPlace),
      candidateId: _candidateIdForCheckin(selectedPlace),
      mediaId: mediaId,
      mediaType: checkinMediaTypeForSource(source),
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
