import 'package:fidey_mobile/models/camera_share_audience.dart';
import 'package:fidey_mobile/models/selected_place_tag.dart';
import 'package:fidey_mobile/services/auth_service.dart';
import 'package:fidey_mobile/services/checkin_service.dart';
import 'package:fidey_mobile/services/place_candidate_service.dart';
import 'package:fidey_mobile/services/send_image_publisher.dart';
import 'package:fidey_mobile/services/upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(isTestMode: true);
}

class _FakeUploadService extends UploadService {
  _FakeUploadService() : super(authService: _FakeAuthService());

  String? uploadedImagePath;
  double? uploadedLatitude;
  double? uploadedLongitude;
  String? uploadedSource;
  String? uploadedContentTypeOverride;
  int? uploadedDurationMs;

  @override
  Future<String> upload({
    required String imagePath,
    required double longitude,
    required double latitude,
    required String source,
    String? contentTypeOverride,
    int? durationMs,
    void Function(double progress)? onProgress,
  }) async {
    uploadedImagePath = imagePath;
    uploadedLatitude = latitude;
    uploadedLongitude = longitude;
    uploadedSource = source;
    uploadedContentTypeOverride = contentTypeOverride;
    uploadedDurationMs = durationMs;
    return 'media-1';
  }
}

class _FakeCheckinService extends CheckinService {
  _FakeCheckinService() : super(_FakeAuthService());

  String? placeId;
  String? candidateId;
  String? mediaId;
  double? gpsLat;
  double? gpsLng;
  String? caption;
  CameraShareAudience? audience;
  String? mediaType;

  @override
  Future<CheckinResult> createCheckin({
    String? placeId,
    String? candidateId,
    required String mediaId,
    String? mediaType,
    required double gpsLat,
    required double gpsLng,
    double? gpsAccuracy,
    String? caption,
    int? rating,
    required CameraShareAudience audience,
  }) async {
    this.placeId = placeId;
    this.candidateId = candidateId;
    this.mediaId = mediaId;
    this.mediaType = mediaType;
    this.gpsLat = gpsLat;
    this.gpsLng = gpsLng;
    this.caption = caption;
    this.audience = audience;
    return const CheckinResult(
      checkinId: 'checkin-1',
      createdAt: '2026-06-12T01:00:00.000Z',
    );
  }
}

class _FakePlaceCandidateService extends PlaceCandidateService {
  _FakePlaceCandidateService() : super(_FakeAuthService());

  String? name;
  String? category;
  String? mediaId;
  double? lat;
  double? lng;
  String? address;
  String? visibility;

  @override
  Future<PlaceCandidateResponse> createCandidate({
    required String name,
    required String category,
    required String mediaId,
    required double lat,
    required double lng,
    bool force = false,
    String? address,
    String? openTime,
    String? closeTime,
    int? priceMin,
    int? priceMax,
    String? phoneNumber,
    String? description,
    String visibility = 'FRIENDS',
  }) async {
    this.name = name;
    this.category = category;
    this.mediaId = mediaId;
    this.lat = lat;
    this.lng = lng;
    this.address = address;
    this.visibility = visibility;

    return const PlaceCandidateResponse(
      status: 'created',
      data: PlaceCandidateData(
        candidateId: 'candidate-created',
        name: 'New Cafe',
        category: 'restaurant',
        status: 'PENDING_REVIEW',
        visibility: 'PRIVATE',
        createdAt: '2026-07-07T01:00:00.000Z',
      ),
    );
  }
}

void main() {
  test(
    'uploads media then creates a check-in with selected audience',
    () async {
      final uploadService = _FakeUploadService();
      final checkinService = _FakeCheckinService();
      final publisher = SendImagePublisher(
        uploadService: uploadService,
        checkinService: checkinService,
      );
      final audience = CameraShareAudience.allFriends();

      final result = await publisher.publish(
        imagePath: 'image.jpg',
        source: 'IN_APP_CAMERA',
        selectedPlace: const SelectedPlaceTag(
          id: 'place-1',
          placeId: 'place-1',
          displayName: 'Cafe',
          address: '123 Street',
          lat: 10.7738,
          lng: 106.7035,
          source: 'internal',
        ),
        audience: audience,
        caption: 'Hello',
      );

      expect(result.checkinId, 'checkin-1');
      expect(uploadService.uploadedImagePath, 'image.jpg');
      expect(uploadService.uploadedLatitude, 10.7738);
      expect(uploadService.uploadedLongitude, 106.7035);
      expect(uploadService.uploadedSource, 'IN_APP_CAMERA');
      expect(checkinService.placeId, 'place-1');
      expect(checkinService.candidateId, isNull);
      expect(checkinService.mediaId, 'media-1');
      expect(checkinService.gpsLat, 10.7738);
      expect(checkinService.gpsLng, 106.7035);
      expect(checkinService.caption, 'Hello');
      expect(checkinService.audience, same(audience));
    },
  );

  test(
    'passes video duration metadata to upload service',
    () async {
      final uploadService = _FakeUploadService();
      final checkinService = _FakeCheckinService();
      final publisher = SendImagePublisher(
        uploadService: uploadService,
        checkinService: checkinService,
      );

      await publisher.publish(
        imagePath: 'clip.mp4',
        source: 'IN_APP_CAMERA_VIDEO',
        durationMs: 3000,
        selectedPlace: const SelectedPlaceTag(
          id: 'place-1',
          placeId: 'place-1',
          displayName: 'Cafe',
          address: '123 Street',
          lat: 10.7738,
          lng: 106.7035,
          source: 'internal',
        ),
        audience: CameraShareAudience.allFriends(),
      );

      expect(uploadService.uploadedSource, 'IN_APP_CAMERA_VIDEO');
      expect(uploadService.uploadedDurationMs, 3000);
      expect(checkinService.mediaType, 'VIDEO');
    },
  );

  test(
    'uses candidate id when selected place has no canonical place id',
    () async {
      final checkinService = _FakeCheckinService();
      final publisher = SendImagePublisher(
        uploadService: _FakeUploadService(),
        checkinService: checkinService,
      );

      await publisher.publish(
        imagePath: 'image.jpg',
        source: 'EXIF_GALLERY',
        selectedPlace: const SelectedPlaceTag(
          id: 'candidate-1',
          displayName: 'New Cafe',
          address: '123 Street',
          lat: 10.7738,
          lng: 106.7035,
          source: 'custom',
        ),
        audience: CameraShareAudience.allFriends(),
      );

      expect(checkinService.placeId, isNull);
      expect(checkinService.candidateId, 'candidate-1');
    },
  );

  test(
    'creates pending custom place after upload so candidate receives media id',
    () async {
      final checkinService = _FakeCheckinService();
      final placeCandidateService = _FakePlaceCandidateService();
      final publisher = SendImagePublisher(
        uploadService: _FakeUploadService(),
        checkinService: checkinService,
        placeCandidateService: placeCandidateService,
      );

      await publisher.publish(
        imagePath: 'image.jpg',
        source: 'IN_APP_CAMERA',
        selectedPlace: const SelectedPlaceTag(
          id: 'custom-pending-1',
          displayName: 'New Cafe',
          address: '123 Street',
          lat: 10.7738,
          lng: 106.7035,
          source: 'custom_pending',
          customVisibility: 'PRIVATE',
        ),
        audience: CameraShareAudience.allFriends(),
      );

      expect(placeCandidateService.name, 'New Cafe');
      expect(placeCandidateService.category, 'restaurant');
      expect(placeCandidateService.mediaId, 'media-1');
      expect(placeCandidateService.address, '123 Street');
      expect(placeCandidateService.visibility, 'PRIVATE');
      expect(checkinService.placeId, isNull);
      expect(checkinService.candidateId, 'candidate-created');
      expect(checkinService.mediaId, 'media-1');
    },
  );
}
