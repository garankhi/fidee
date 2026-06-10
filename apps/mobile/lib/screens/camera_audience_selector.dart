import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/camera_checkin_feed_item.dart';
import '../services/friend_service.dart';

class CameraAudienceSelector extends StatefulWidget {
  final CameraFeedAudience selectedAudience;
  final List<FriendProfile> friends;
  final ValueChanged<CameraFeedAudience> onSelected;

  const CameraAudienceSelector({
    super.key,
    required this.selectedAudience,
    required this.friends,
    required this.onSelected,
  });

  @override
  State<CameraAudienceSelector> createState() => _CameraAudienceSelectorState();
}

class _CameraAudienceSelectorState extends State<CameraAudienceSelector> {
  bool _isOpen = false;

  void _select(CameraFeedAudience audience) {
    setState(() => _isOpen = false);
    widget.onSelected(audience);
  }

  @override
  Widget build(BuildContext context) {
    final dropdownHeight = math.min((widget.friends.length + 2) * 78.0, 560.0);

    return SizedBox(
      height: _isOpen ? 72 + dropdownHeight : 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          GestureDetector(
            key: const ValueKey('camera-audience-pill'),
            onTap: () => setState(() => _isOpen = !_isOpen),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.selectedAudience.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    color: Colors.white70,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
          if (_isOpen)
            Positioned(
              key: const ValueKey('camera-audience-dropdown'),
              top: 72,
              child: _AudienceDropdown(
                friends: widget.friends,
                onSelected: _select,
              ),
            ),
        ],
      ),
    );
  }
}

class _AudienceDropdown extends StatelessWidget {
  final List<FriendProfile> friends;
  final ValueChanged<CameraFeedAudience> onSelected;

  const _AudienceDropdown({required this.friends, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width - 72, 390.0);

    return Container(
      width: width,
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AudienceRow(
              key: const ValueKey('camera-audience-everyone'),
              icon: LucideIcons.usersRound,
              label: 'Mọi người',
              onTap: () => onSelected(CameraFeedAudience.everyone()),
            ),
            _AudienceRow(
              key: const ValueKey('camera-audience-me'),
              label: 'Bạn',
              onTap: () => onSelected(CameraFeedAudience.me()),
            ),
            for (final friend in friends)
              _AudienceRow(
                key: ValueKey('camera-audience-friend-${friend.id}'),
                label: friend.name,
                avatarUrl: friend.avatarUrl,
                initials: friend.initials,
                onTap: () => onSelected(
                  CameraFeedAudience.friend(
                    id: friend.id,
                    label: friend.name,
                    avatarUrl: friend.avatarUrl,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AudienceRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? avatarUrl;
  final String? initials;
  final VoidCallback onTap;

  const _AudienceRow({
    super.key,
    this.icon,
    required this.label,
    this.avatarUrl,
    this.initials,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
          ),
        ),
        child: Row(
          children: [
            _AudienceAvatar(
              icon: icon,
              avatarUrl: avatarUrl,
              initials: initials ?? label.characters.first.toUpperCase(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: Colors.white.withValues(alpha: 0.58),
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}

class _AudienceAvatar extends StatelessWidget {
  final IconData? icon;
  final String? avatarUrl;
  final String initials;

  const _AudienceAvatar({this.icon, this.avatarUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        child: Icon(icon, color: Colors.white, size: 28),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFF262626),
      backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl!),
      child: avatarUrl == null
          ? Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}
