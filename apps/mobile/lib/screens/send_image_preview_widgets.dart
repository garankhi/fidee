import 'package:flutter/material.dart';

import '../models/camera_share_audience.dart';
import '../services/friend_service.dart';
import '../widgets/glass_surface.dart';

class SendImagePlaceTagPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const SendImagePlaceTagPill({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassSurface(
        key: const ValueKey('send-image-place-tag-pill'),
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        tint: const Color(0x26FFFFFF),
        borderColor: const Color(0x66FFFFFF),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'SF Pro',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SendImageShareAudienceSelector extends StatelessWidget {
  final CameraShareAudience selectedAudience;
  final List<FriendProfile> friends;
  final ValueChanged<CameraShareAudience> onSelected;

  const SendImageShareAudienceSelector({
    super.key,
    required this.selectedAudience,
    required this.friends,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('send-image-share-audience-selector'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Cùng với',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _ShareAudienceChip(
                key: const ValueKey('send-image-audience-all'),
                label: 'Tất cả',
                isSelected:
                    selectedAudience.type == CameraShareAudienceType.allFriends,
                icon: Icons.people_alt,
                onTap: () => onSelected(CameraShareAudience.allFriends()),
              ),
              for (final friend in friends)
                _ShareAudienceChip(
                  key: ValueKey('send-image-audience-friend-${friend.id}'),
                  label: friend.handle.isNotEmpty ? friend.handle : friend.name,
                  initials: friend.initials,
                  avatarUrl: friend.avatarUrl,
                  isSelected:
                      selectedAudience.type == CameraShareAudienceType.direct &&
                      selectedAudience.friendIds.contains(friend.id),
                  onTap: () => onSelected(
                    selectedAudience.toggleFriend(friend, friends),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareAudienceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? initials;
  final String? avatarUrl;

  const _ShareAudienceChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.initials,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isSelected ? Colors.amber : Colors.transparent;
    final textColor = isSelected ? Colors.amber : Colors.white54;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 2),
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[850],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildAvatar(),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  color: textColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final url = avatarUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackAvatar(),
      );
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    final glyph = icon;
    if (glyph != null) {
      return Icon(glyph, color: Colors.white, size: 24);
    }

    return Center(
      child: Text(
        initials ?? '?',
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
