import 'dart:math';

/// Response from POST /place-candidates
class PlaceCandidateResponse {
  final String status;
  final PlaceCandidateData? data;
  final PlaceCandidateError? error;
  final List<ConflictCandidate>? candidates;

  const PlaceCandidateResponse({
    required this.status,
    this.data,
    this.error,
    this.candidates,
  });

  bool get isCreated => status == 'created';
  bool get isConflict => status == 'conflict';
  bool get isQuotaExceeded => error?.code == 'QUOTA_EXCEEDED';
}

class PlaceCandidateData {
  final String candidateId;
  final String name;
  final String category;
  final String status;
  final String visibility;
  final String createdAt;

  const PlaceCandidateData({
    required this.candidateId,
    required this.name,
    required this.category,
    required this.status,
    required this.visibility,
    required this.createdAt,
  });
}

class PlaceCandidateError {
  final String code;
  final String message;
  final int? dailyLimit;
  final int? used;

  const PlaceCandidateError({
    required this.code,
    required this.message,
    this.dailyLimit,
    this.used,
  });
}

class ConflictCandidate {
  final String candidateId;
  final String name;
  final int distanceMeters;

  const ConflictCandidate({
    required this.candidateId,
    required this.name,
    required this.distanceMeters,
  });
}

/// Service for creating custom place candidates.
/// Currently returns mock data. Will call POST /place-candidates when BE is ready.
class PlaceCandidateService {
  static int _mockCallCount = 0;

  /// Create a new place candidate.
  static Future<PlaceCandidateResponse> createCandidate({
    required String name,
    required String category,
    required String mediaId,
    required double lat,
    required double lng,
    bool force = false,
  }) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    _mockCallCount++;

    // Simulate quota exceeded after 5 calls
    if (_mockCallCount > 5 && !force) {
      return const PlaceCandidateResponse(
        status: 'error',
        error: PlaceCandidateError(
          code: 'QUOTA_EXCEEDED',
          message: 'Bạn đã đạt giới hạn 5 địa điểm/ngày',
          dailyLimit: 5,
          used: 5,
        ),
      );
    }

    // Simulate near-duplicate on 3rd call (unless force)
    if (_mockCallCount == 3 && !force) {
      return PlaceCandidateResponse(
        status: 'conflict',
        error: const PlaceCandidateError(
          code: 'NEAR_DUPLICATE',
          message: 'Tìm thấy địa điểm tương tự gần đây',
        ),
        candidates: [
          ConflictCandidate(
            candidateId: 'cand_existing_001',
            name: '$name (đã tạo trước đó)',
            distanceMeters: 45,
          ),
        ],
      );
    }

    // Success
    final id = 'cand_${Random().nextInt(999999).toString().padLeft(6, '0')}';
    return PlaceCandidateResponse(
      status: 'created',
      data: PlaceCandidateData(
        candidateId: id,
        name: name,
        category: category,
        status: 'PENDING_REVIEW',
        visibility: 'FRIENDS',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Reset mock state (for testing)
  static void resetMock() {
    _mockCallCount = 0;
  }
}
