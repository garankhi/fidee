import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/candidate_provider.dart';
import 'place_details_friends.dart';

class CandidateFeedScreen extends ConsumerStatefulWidget {
  const CandidateFeedScreen({super.key});

  @override
  ConsumerState<CandidateFeedScreen> createState() =>
      _CandidateFeedScreenState();
}

class _CandidateFeedScreenState
    extends ConsumerState<CandidateFeedScreen> {

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref
          .read(candidateControllerProvider.notifier)
          .loadCandidates(
        lat: 10.762622,
        lng: 106.660172,
        radiusKm: 20,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final candidatesAsync =
    ref.watch(candidateControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),

      appBar: AppBar(
        title: const Text(
          'Địa điểm chờ duyệt',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFEF484F),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),

      body: candidatesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),

        error: (err, _) => Center(
          child: Text('Đã xảy ra lỗi: $err'),
        ),

        data: (candidates) {
          if (candidates.isEmpty) {
            return const Center(
              child: Text(
                'Không có địa điểm nào trong bán kính 20km',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(candidateControllerProvider.notifier)
                  .refresh(
                lat: 10.762622,
                lng: 106.660172,
                radiusKm: 20,
              );
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final candidate = candidates[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PlaceDetailsFriends(
                          placeId: candidate.id,
                        ),
                      ),
                    );
                  },
                  child: _buildCandidateCard(candidate),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCandidateCard(CandidatePlace place) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEAEAEA),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Expanded(
                child: Text(
                  place.name ?? 'Chưa có tên',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEDEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${place.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: Color(0xFFEF484F),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            place.address ?? 'Chưa có địa chỉ',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 12),

          if (place.category != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F6F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                place.category!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          if (place.description != null &&
              place.description!.isNotEmpty) ...[
            const SizedBox(height: 12),

            Text(
              place.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 16,
                color: Colors.grey,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  place.createdByName ??
                      place.createdByUsername ??
                      'Người dùng',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),

              Text(
                '${place.distanceMeters} m',
                style: const TextStyle(
                  color: Color(0xFFEF484F),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}