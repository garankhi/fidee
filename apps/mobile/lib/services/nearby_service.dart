import '../models/nearby_place.dart';

/// Service that provides nearby places data.
/// Currently returns mock data matching the API contract.
/// Will be replaced with real API calls when backend is ready.
class NearbyService {
  /// Fetch nearby places based on coordinates.
  /// In MVP, returns mock data from the contract.
  Future<NearbyResponse> fetchNearby({
    required double lat,
    required double lng,
    int radius = 50,
    required String mediaId,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Return mock data matching nearby_mock_success.json
    return NearbyResponse.fromJson(_mockSuccessResponse(lat, lng));
  }

  static Map<String, dynamic> _mockSuccessResponse(double lat, double lng) {
    return {
      "status": "success",
      "metadata": {
        "source": "goong_places",
        "has_goong_fallback": true,
        "total_results": 3,
      },
      "data": [
        {
          "id": "place_mapvibe_001",
          "place_id": "goong_pid_98765",
          "source": "goong_places",
          "display_name": "Bitexco Financial Tower",
          "address": "2 Hải Triều, Bến Nghé, Quận 1, Hồ Chí Minh",
          "category": "tourist_attraction",
          "distance_meters": 5,
          "confidence": "high",
          "coordinates": {"lat": 10.771597, "lng": 106.704416},
          "actions": {"primary": "attach_place_to_photo"},
        },
        {
          "id": "place_mapvibe_002",
          "place_id": "goong_pid_43210",
          "source": "goong_places",
          "display_name": "Katinat Saigon Kafe",
          "address": "91 Đồng Khởi, Bến Nghé, Quận 1, Hồ Chí Minh",
          "category": "cafe",
          "distance_meters": 28,
          "confidence": "medium",
          "coordinates": {"lat": 10.771800, "lng": 106.704600},
          "actions": {"primary": "attach_place_to_photo"},
        },
        {
          "id": "place_mapvibe_003",
          "place_id": "goong_pid_55555",
          "source": "goong_places",
          "display_name": "The Coffee House - Hai Trieu",
          "address": "5 Hải Triều, Bến Nghé, Quận 1, Hồ Chí Minh",
          "category": "cafe",
          "distance_meters": 42,
          "confidence": "low",
          "coordinates": {"lat": 10.771900, "lng": 106.704200},
          "actions": {"primary": "attach_place_to_photo"},
        },
        {
          "id": "custom_fallback",
          "place_id": null,
          "source": "custom",
          "display_name": "Tạo địa điểm mới tại đây",
          "address": "Gần 2 Hải Triều, Quận 1, Hồ Chí Minh",
          "category": "custom",
          "distance_meters": 0,
          "confidence": "low",
          "coordinates": {"lat": lat, "lng": lng},
          "actions": {"primary": "create_custom_place"},
        },
      ],
    };
  }
}
