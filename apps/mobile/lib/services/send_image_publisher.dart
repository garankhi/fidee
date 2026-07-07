import '../models/camera_share_audience.dart';
import '../models/selected_place_tag.dart';
import 'checkin_service.dart';
import 'place_candidate_service.dart';
import 'upload_service.dart';

String checkinMediaTypeForSource(String source) {
  return source.endsWith('_VIDEO') ? 'VIDEO' : 'IMAGE';
}

class SendImagePublisher {
  final UploadService uploadService;
  final CheckinService checkinService;
  final PlaceCandidateService? placeCandidateService;

  const SendImagePublisher({
    required this.uploadService,
    required this.checkinService,
    this.placeCandidateService,
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

    final checkinPlace = await _resolveCheckinPlace(selectedPlace, mediaId);

    return checkinService.createCheckin(
      placeId: _placeIdForCheckin(checkinPlace),
      candidateId: _candidateIdForCheckin(checkinPlace),
      mediaId: mediaId,
      mediaType: checkinMediaTypeForSource(source),
      gpsLat: checkinPlace.lat,
      gpsLng: checkinPlace.lng,
      caption: caption,
      audience: audience,
    );
  }

  Future<SelectedPlaceTag> _resolveCheckinPlace(
    SelectedPlaceTag place,
    String mediaId,
  ) async {
    if (place.source != 'custom_pending') return place;

    final service = placeCandidateService;
    if (service == null) {
      throw const CheckinException('Không tạo được địa điểm mới, vui lòng thử lại');
    }

    final response = await service.createCandidate(
      name: place.displayName,
      category: 'restaurant',
      mediaId: mediaId,
      lat: place.lat,
      lng: place.lng,
      address: place.address.trim().isEmpty ? null : place.address.trim(),
      visibility: place.customVisibility ?? 'FRIENDS',
    );

    final data = response.data;
    if (!response.isCreated || data == null) {
      throw CheckinException(_candidateErrorMessage(response));
    }

    return SelectedPlaceTag(
      id: data.candidateId,
      displayName: data.name,
      address: place.address,
      lat: place.lat,
      lng: place.lng,
      source: 'custom',
    );
  }

  String _candidateErrorMessage(PlaceCandidateResponse response) {
    if (response.isConflict) return 'Địa điểm này có vẻ đã tồn tại gần đây';
    if (response.isQuotaExceeded) return 'Bạn đã đạt giới hạn tạo địa điểm hôm nay';
    return response.error?.message ?? 'Không tạo được địa điểm mới, vui lòng thử lại';
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
