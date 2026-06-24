import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/dashboard_provider.dart';
import '../models/dashboard_place.dart';
import 'place_details_friends.dart';

class SearchResultScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialVibe;

  const SearchResultScreen({
    super.key,
    this.initialQuery,
    this.initialVibe,
  });

  @override
  ConsumerState<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends ConsumerState<SearchResultScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery ?? '';

    Future.microtask(() {
      if (widget.initialVibe != null) {
        ref.read(dashboardControllerProvider.notifier).selectVibe(widget.initialVibe!);
      } else if (widget.initialQuery != null) {
        ref.read(dashboardControllerProvider.notifier).search(query: widget.initialQuery!);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch(String value) {
    if (value.trim().isNotEmpty) {
      ref.read(dashboardControllerProvider.notifier).search(query: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              ref.read(dashboardControllerProvider.notifier).clearSearch();
              Navigator.pop(context);
            },
          ),
          title: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _searchController,
              onSubmitted: _submitSearch,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Colors.black, fontSize: 13),
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                hintText: 'Tìm nhà hàng, quán ăn..',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildSearchResults(dashboardState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(DashboardState state) {
    if (state.isSearching && state.searchResults.isEmpty) {
      return const _DiscoverySearchSkeleton();
    }

    if (state.searchResults.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy địa điểm phù hợp.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: state.searchResults.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.searchResults.length) {
          return Center(
            child: TextButton.icon(
              onPressed: state.isLoadingMore
                  ? null
                  : () => ref.read(dashboardControllerProvider.notifier).loadMore(),
              icon: state.isLoadingMore
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.expand_more),
              label: const Text('Xem thêm'),
            ),
          );
        }

        return _buildSearchPlaceRow(state.searchResults[index]);
      },
    );
  }

  Widget _buildSearchPlaceRow(DashboardPlace place) {
    final tags = <String>[
      place.category,
      ...place.vibes.take(2),
    ];
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PlaceDetailsFriends(placeId: place.id),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                place.imageUrl,
                width: 92,
                height: 92,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 92,
                  height: 92,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.storefront),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '★ ${place.rating.toStringAsFixed(1)} · '
                        '${place.distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Color(0xFF6E7E91),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags
                        .map(
                          (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFECEF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Color(0xFFEF4050),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _DiscoverySearchSkeleton extends StatelessWidget {
  const _DiscoverySearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: 4,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 150,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 110,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}