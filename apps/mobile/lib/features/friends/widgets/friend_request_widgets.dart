import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../services/friend_service.dart';

enum FriendRequestTone { dark, light }

class FriendRequestBadge extends StatelessWidget {
  final int count;

  const FriendRequestBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    return Semantics(
      label: '$count lời mời kết bạn',
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFC400),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class FriendRequestSummaryBanner extends StatelessWidget {
  final int count;
  final VoidCallback onOpen;

  const FriendRequestSummaryBanner({
    super.key,
    required this.count,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFECEF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEF4050).withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.userRoundCheck, color: Color(0xFFEF4050), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bạn có $count lời mời kết bạn',
                style: const TextStyle(
                  color: Color(0xFF151515),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4050),
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Xem'),
            ),
          ],
        ),
      ),
    );
  }
}

class FriendRequestActionRow extends StatelessWidget {
  final FriendProfile request;
  final FriendRequestTone tone;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const FriendRequestActionRow({
    super.key,
    required this.request,
    required this.tone,
    required this.isBusy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = tone == FriendRequestTone.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF151515);
    final secondaryText = isDark ? Colors.white.withValues(alpha: 0.56) : const Color(0xFF8D8D8D);
    final declineBackground = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFFFECEF);
    final declineForeground = isDark ? Colors.white : const Color(0xFFEF4050);

    return Row(
      children: [
        _RequestAvatar(profile: request),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (request.handle.isNotEmpty)
                Text(
                  '@${request.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        IconButton.filled(
          key: ValueKey('friend-request-accept-${request.id}'),
          onPressed: isBusy ? null : onAccept,
          style: IconButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFFFFC400) : const Color(0xFFEF4050),
            foregroundColor: isDark ? Colors.black : Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          icon: const Icon(LucideIcons.check, size: 20),
          tooltip: 'Chấp nhận',
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          key: ValueKey('friend-request-decline-${request.id}'),
          onPressed: isBusy ? null : onDecline,
          style: IconButton.styleFrom(
            backgroundColor: declineBackground,
            foregroundColor: declineForeground,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          icon: const Icon(LucideIcons.x, size: 20),
          tooltip: 'Từ chối',
        ),
      ],
    );
  }
}

class _RequestAvatar extends StatelessWidget {
  final FriendProfile profile;

  const _RequestAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFD4DA),
        image: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
            ? DecorationImage(image: NetworkImage(profile.avatarUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
          ? Center(
              child: Text(
                profile.initials,
                style: const TextStyle(
                  color: Color(0xFFEF4050),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : null,
    );
  }
}
