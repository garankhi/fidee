import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../services/friend_service.dart';
import 'friend_request_widgets.dart';

class FriendSearchResultActionRow extends StatelessWidget {
  final FriendSearchResult result;
  final FriendRequestTone tone;
  final bool isBusy;
  final VoidCallback? onAdd;
  final VoidCallback? onCancel;
  final VoidCallback? onAccept;

  const FriendSearchResultActionRow({
    super.key,
    required this.result,
    required this.tone,
    required this.isBusy,
    this.onAdd,
    this.onCancel,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = tone == FriendRequestTone.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF151515);
    final secondaryText = isDark
        ? Colors.white.withValues(alpha: 0.56)
        : const Color(0xFF8D8D8D);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _SearchAvatar(profile: result.profile, tone: tone),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: isDark ? 19 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (result.profile.handle.isNotEmpty)
                  Text(
                    '@${result.profile.handle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: isDark ? 13 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          _SearchResultActionButton(
            result: result,
            tone: tone,
            isBusy: isBusy,
            onAdd: onAdd,
            onCancel: onCancel,
            onAccept: onAccept,
          ),
        ],
      ),
    );
  }
}

class _SearchResultActionButton extends StatelessWidget {
  final FriendSearchResult result;
  final FriendRequestTone tone;
  final bool isBusy;
  final VoidCallback? onAdd;
  final VoidCallback? onCancel;
  final VoidCallback? onAccept;

  const _SearchResultActionButton({
    required this.result,
    required this.tone,
    required this.isBusy,
    required this.onAdd,
    required this.onCancel,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = tone == FriendRequestTone.dark;
    final config = _buttonConfig(isDark);

    return ElevatedButton.icon(
      key: ValueKey(config.key),
      onPressed: isBusy ? null : config.onPressed,
      icon: Icon(config.icon, size: 16),
      label: Text(config.label),
      style: ElevatedButton.styleFrom(
        backgroundColor: config.background,
        foregroundColor: config.foreground,
        disabledBackgroundColor: isDark
            ? const Color(0xFF575757)
            : const Color(0xFFE5E7EB),
        disabledForegroundColor: isDark
            ? Colors.white70
            : const Color(0xFF6B7280),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDark ? 18 : 10),
        ),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }

  _ActionButtonConfig _buttonConfig(bool isDark) {
    if (result.canRequest) {
      return _ActionButtonConfig(
        key: 'friend-add-${result.profile.id}',
        label: 'Thêm',
        icon: LucideIcons.userPlus,
        background: isDark ? const Color(0xFFFFC400) : const Color(0xFFEF4050),
        foreground: isDark ? Colors.black : Colors.white,
        onPressed: onAdd,
      );
    }
    if (result.canCancelRequest) {
      return _ActionButtonConfig(
        key: 'friend-cancel-${result.profile.id}',
        label: 'Hủy gửi',
        icon: LucideIcons.x,
        background: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFFFECEF),
        foreground: isDark ? Colors.white : const Color(0xFFEF4050),
        onPressed: onCancel,
      );
    }
    if (result.canAcceptRequest) {
      return _ActionButtonConfig(
        key: 'friend-accept-${result.profile.id}',
        label: 'Chấp nhận',
        icon: LucideIcons.check,
        background: isDark ? const Color(0xFFFFC400) : const Color(0xFFEF4050),
        foreground: isDark ? Colors.black : Colors.white,
        onPressed: onAccept,
      );
    }

    return _ActionButtonConfig(
      key: 'friend-status-${result.profile.id}',
      label: _statusLabel(result.relationStatus),
      icon: LucideIcons.check,
      background: isDark ? const Color(0xFF575757) : const Color(0xFFE5E7EB),
      foreground: isDark ? Colors.white70 : const Color(0xFF6B7280),
      onPressed: null,
    );
  }

  String _statusLabel(FriendRelationStatus status) {
    switch (status) {
      case FriendRelationStatus.pending:
        return 'Đã gửi';
      case FriendRelationStatus.accepted:
        return 'Bạn bè';
      case FriendRelationStatus.blocked:
        return 'Đã chặn';
      case FriendRelationStatus.none:
      case FriendRelationStatus.unknown:
        return 'Thêm';
    }
  }
}

class _ActionButtonConfig {
  final String key;
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  const _ActionButtonConfig({
    required this.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });
}

class _SearchAvatar extends StatelessWidget {
  final FriendProfile profile;
  final FriendRequestTone tone;

  const _SearchAvatar({required this.profile, required this.tone});

  @override
  Widget build(BuildContext context) {
    final isDark = tone == FriendRequestTone.dark;
    final size = isDark ? 58.0 : 48.0;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(isDark ? 4 : 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFFFFC400) : const Color(0xFFFFD4DA),
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        backgroundColor: isDark
            ? const Color(0xFF393939)
            : const Color(0xFFFFD4DA),
        backgroundImage: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
            ? null
            : NetworkImage(profile.avatarUrl!),
        child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
            ? Text(
                profile.initials,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFFEF4050),
                  fontSize: size * 0.26,
                  fontWeight: FontWeight.w900,
                ),
              )
            : null,
      ),
    );
  }
}
