import 'dart:io';
import 'package:flutter/material.dart';
import '../models/nearby_place.dart';
import '../services/nearby_service.dart';

/// Bottom sheet that shows nearby places after a photo is taken.
/// Uses mock data from the API contract for MVP.
class NearbyPlacesSheet extends StatefulWidget {
  final File photo;
  final double lat;
  final double lng;

  const NearbyPlacesSheet({
    super.key,
    required this.photo,
    required this.lat,
    required this.lng,
  });

  /// Show the bottom sheet and return the selected place (or null).
  static Future<NearbyPlace?> show(
    BuildContext context, {
    required File photo,
    required double lat,
    required double lng,
  }) {
    return showModalBottomSheet<NearbyPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NearbyPlacesSheet(photo: photo, lat: lat, lng: lng),
    );
  }

  @override
  State<NearbyPlacesSheet> createState() => _NearbyPlacesSheetState();
}

class _NearbyPlacesSheetState extends State<NearbyPlacesSheet> {
  final NearbyService _nearbyService = NearbyService();
  NearbyResponse? _response;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    try {
      final response = await _nearbyService.fetchNearby(
        lat: widget.lat,
        lng: widget.lng,
        mediaId: 'photo_mock_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() {
        _response = response;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Khong the tai dia diem gan day';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141821),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Photo preview + header
              _buildHeader(),

              const Divider(color: Color(0xFF2A2F3E), height: 1),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoading()
                    : _error != null
                        ? _buildError()
                        : _buildPlacesList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          // Photo thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              widget.photo,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chon dia diem',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gan anh vao dia diem gan ban',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Close
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.6), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF3B82F6)),
          SizedBox(height: 16),
          Text(
            'Dang tim dia diem gan day...',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.white.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesList(ScrollController scrollController) {
    final places = _response!.data;
    final hasGoong = _response!.metadata.hasGoongFallback;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: places.length + (hasGoong ? 0 : 1), // +1 for goong down banner
      itemBuilder: (context, index) {
        // Show goong down banner at top
        if (!hasGoong && index == 0) {
          return _buildGoongDownBanner();
        }

        final place = places[hasGoong ? index : index - 1];

        if (place.isCustomFallback) {
          return _buildCustomFallbackTile(place);
        }

        return _buildPlaceTile(place);
      },
    );
  }

  Widget _buildGoongDownBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Color(0xFFF59E0B), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dich vu ban do tam thoi khong kha dung. Ban co the tao dia diem moi.',
              style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceTile(NearbyPlace place) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, place),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: place.confidence == 'high'
                ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _categoryColor(place.category).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _categoryIcon(place.category),
                color: _categoryColor(place.category),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          place.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (place.confidence == 'high')
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Gan nhat',
                            style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.address,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Distance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${place.distanceMeters}m',
                  style: TextStyle(
                    color: _confidenceColor(place.confidence),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFallbackTile(NearbyPlace place) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, place),
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            width: 1.5,
          ),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF3B82F6).withValues(alpha: 0.08),
              const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.25),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_location_alt, color: Color(0xFF3B82F6), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tao dia diem moi tai day',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.address,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: const Color(0xFF3B82F6).withValues(alpha: 0.6), size: 16),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'cafe':
        return const Color(0xFFF59E0B);
      case 'restaurant':
        return const Color(0xFFEF4444);
      case 'tourist_attraction':
        return const Color(0xFF8B5CF6);
      case 'hotel':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'cafe':
        return Icons.coffee;
      case 'restaurant':
        return Icons.restaurant;
      case 'tourist_attraction':
        return Icons.photo_camera;
      case 'hotel':
        return Icons.hotel;
      default:
        return Icons.place;
    }
  }

  Color _confidenceColor(String confidence) {
    switch (confidence) {
      case 'high':
        return const Color(0xFF22C55E);
      case 'medium':
        return Colors.white;
      case 'low':
        return Colors.white54;
      default:
        return Colors.white54;
    }
  }
}
