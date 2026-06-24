import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/camera_checkin_feed_item.dart';
import '../services/friend_service.dart';

class CameraAudienceSelector extends StatefulWidget {
  final CameraFeedAudience selectedAudience;
  final List<FriendProfile> friends;
  final String? currentUserAvatarUrl;
  final String currentUserInitials;
  final ValueChanged<CameraFeedAudience> onSelected;
  final ValueChanged<bool>? onOpenChanged;

  const CameraAudienceSelector({
    super.key,
    required this.selectedAudience,
    required this.friends,
    this.currentUserAvatarUrl,
    this.currentUserInitials = 'B',
    required this.onSelected,
    this.onOpenChanged,
  });

  @override
  State<CameraAudienceSelector> createState() => _CameraAudienceSelectorState();
}

class _CameraAudienceSelectorState extends State<CameraAudienceSelector> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  bool _isOpen = false;

  void _setOpen(bool value) {
    if (_isOpen == value) return;
    setState(() => _isOpen = value);
    if (value) {
      _overlayController.show();
    } else {
      _overlayController.hide();
    }
    widget.onOpenChanged?.call(value);
  }

  void _toggle() => _setOpen(!_isOpen);

  void _select(CameraFeedAudience audience) {
    _setOpen(false);
    widget.onSelected(audience);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          return Positioned.fill(
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _setOpen(false),
                ),
                CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.bottomCenter,
                  followerAnchor: Alignment.topCenter,
                  offset: const Offset(0, 16),
                  child: Material(
                    color: Colors.transparent,
                    child: _AudienceDropdown(
                      friends: widget.friends,
                      currentUserAvatarUrl: widget.currentUserAvatarUrl,
                      currentUserInitials: widget.currentUserInitials,
                      onSelected: _select,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: GestureDetector(
          key: const ValueKey('camera-audience-pill'),
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  key: const ValueKey('camera-audience-chevron'),
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: const Icon(
                    LucideIcons.chevronDown,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AudienceDropdown extends StatelessWidget {
  final List<FriendProfile> friends;
  final String? currentUserAvatarUrl;
  final String currentUserInitials;
  final ValueChanged<CameraFeedAudience> onSelected;

  const _AudienceDropdown({
    required this.friends,
    required this.currentUserAvatarUrl,
    required this.currentUserInitials,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width - 72, 390.0);

    return Container(
      key: const ValueKey('camera-audience-dropdown'),
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
              avatarKey: const ValueKey('camera-audience-avatar-me'),
              label: 'Bạn',
              avatarUrl: currentUserAvatarUrl,
              initials: currentUserInitials,
              onTap: () => onSelected(
                CameraFeedAudience.me(avatarUrl: currentUserAvatarUrl),
              ),
            ),
            for (final friend in friends)
              _AudienceRow(
                key: ValueKey('camera-audience-friend-${friend.id}'),
                avatarKey: ValueKey('camera-audience-avatar-${friend.id}'),
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
  final Key? avatarKey;
  final IconData? icon;
  final String label;
  final String? avatarUrl;
  final String? initials;
  final VoidCallback onTap;

  const _AudienceRow({
    super.key,
    this.avatarKey,
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
              avatarKey: avatarKey,
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
  final Key? avatarKey;
  final IconData? icon;
  final String? avatarUrl;
  final String initials;

  const _AudienceAvatar({
    this.avatarKey,
    this.icon,
    this.avatarUrl,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return CircleAvatar(
        key: avatarKey,
        radius: 28,
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        child: Icon(icon, color: Colors.white, size: 28),
      );
    }

    return CircleAvatar(
      key: avatarKey,
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
