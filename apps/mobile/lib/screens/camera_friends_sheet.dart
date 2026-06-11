import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../features/auth/friends_provider.dart';
import '../features/friends/widgets/friend_request_widgets.dart';
import '../services/friend_service.dart';

Future<void> showCameraFriendsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CameraFriendsSheet(),
  );
}

class CameraFriendsSheet extends ConsumerWidget {
  const CameraFriendsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsState = ref.watch(friendsControllerProvider);
    final controller = ref.read(friendsControllerProvider.notifier);

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: CameraFriendsSheetContent(
        friends: friendsState.friends,
        requests: friendsState.requests,
        isLoading: friendsState.isLoading,
        onSearchUsers: controller.searchUsers,
        onAddFriend: controller.addFriend,
        onAcceptFriend: controller.accept,
        onDeclineFriend: controller.decline,
        onHideFriend: controller.hide,
        onUnfriend: controller.unfriend,
        onBlockFriend: controller.block,
      ),
    );
  }
}

class CameraFriendsSheetContent extends StatefulWidget {
  final List<FriendProfile> friends;
  final List<FriendProfile> requests;
  final bool isLoading;
  final Future<List<FriendSearchResult>> Function(String username) onSearchUsers;
  final Future<bool> Function(String userId) onAddFriend;
  final Future<bool> Function(String userId) onAcceptFriend;
  final Future<bool> Function(String userId) onDeclineFriend;
  final Future<bool> Function(String userId) onHideFriend;
  final Future<bool> Function(String userId) onUnfriend;
  final Future<bool> Function(String userId) onBlockFriend;

  const CameraFriendsSheetContent({
    super.key,
    required this.friends,
    required this.requests,
    required this.isLoading,
    required this.onSearchUsers,
    required this.onAddFriend,
    required this.onAcceptFriend,
    required this.onDeclineFriend,
    required this.onHideFriend,
    required this.onUnfriend,
    required this.onBlockFriend,
  });

  @override
  State<CameraFriendsSheetContent> createState() => _CameraFriendsSheetContentState();
}

class _CameraFriendsSheetContentState extends State<CameraFriendsSheetContent> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<FriendSearchResult> _searchResults = const <FriendSearchResult>[];
  bool _isExpanded = false;
  bool _isSearching = false;
  String? _activeActionFriendId;
  String? _busyFriendId;
  String? _message;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _searchResults = const <FriendSearchResult>[];
        _isSearching = false;
        _message = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _message = null;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await widget.onSearchUsers(query);
      if (!mounted || _searchController.text.trim().toLowerCase() != query) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _message = results.isEmpty ? 'Không tìm thấy username này' : null;
      });
    });
  }

  Future<void> _runFriendAction(
    String userId,
    Future<bool> Function(String userId) action,
    String successMessage,
  ) async {
    setState(() {
      _busyFriendId = userId;
      _message = null;
      _activeActionFriendId = null;
    });

    final success = await action(userId);
    if (!mounted) return;

    setState(() {
      _busyFriendId = null;
      _message = success ? successMessage : 'Không thực hiện được. Vui lòng thử lại.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleFriends = _isExpanded ? widget.friends : widget.friends.take(3).toList();
    final canToggle = widget.friends.length > 3;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1F1F1F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 14),
              Container(
                width: 56,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '${widget.friends.length} người bạn',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mời một người bạn để tiếp tục',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 28),
              _SearchBox(controller: _searchController, isSearching: _isSearching),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 28, 18, 26),
                  children: [
                    if (_message != null) _InlineMessage(message: _message!),
                    if (widget.requests.isNotEmpty) ...[
                      const _SectionTitle(
                        icon: LucideIcons.userRoundCheck,
                        label: 'Lời mời kết bạn',
                      ),
                      const SizedBox(height: 12),
                      for (final request in widget.requests) ...[
                          FriendRequestActionRow(
                            request: request,
                            tone: FriendRequestTone.dark,
                            isBusy: _busyFriendId == request.id,
                            onAccept: () => _runFriendAction(
                            request.id,
                            widget.onAcceptFriend,
                            'Đã chấp nhận lời mời',
                          ),
                          onDecline: () => _runFriendAction(
                            request.id,
                            widget.onDeclineFriend,
                            'Đã từ chối lời mời',
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 16),
                    ],
                    if (_searchResults.isNotEmpty) ...[
                      const _SectionTitle(icon: LucideIcons.search, label: 'Kết quả tìm kiếm'),
                      const SizedBox(height: 12),
                      for (final result in _searchResults)
                        _SearchResultRow(
                          result: result,
                          isBusy: _busyFriendId == result.profile.id,
                          onAdd: result.canRequest
                              ? () => _runFriendAction(
                                    result.profile.id,
                                    widget.onAddFriend,
                                    'Đã gửi lời mời kết bạn',
                                  )
                              : null,
                        ),
                      const SizedBox(height: 24),
                    ],
                    const _SectionTitle(icon: LucideIcons.users, label: 'Bạn bè của bạn'),
                    const SizedBox(height: 16),
                    if (widget.isLoading && widget.friends.isEmpty)
                      const _FriendListSkeleton()
                    else if (widget.friends.isEmpty)
                      const _EmptyFriendsState()
                    else ...[
                      for (final friend in visibleFriends) ...[
                        _FriendRow(
                          friend: friend,
                          actionKey: ValueKey('friend-action-${friend.id}'),
                          isBusy: _busyFriendId == friend.id,
                          isMenuOpen: _activeActionFriendId == friend.id,
                          onOpenActions: () {
                            setState(() {
                              _activeActionFriendId = _activeActionFriendId == friend.id ? null : friend.id;
                            });
                          },
                          onHide: () => _runFriendAction(friend.id, widget.onHideFriend, 'Đã ẩn bạn bè'),
                          onUnfriend: () => _runFriendAction(friend.id, widget.onUnfriend, 'Đã xóa bạn'),
                          onBlock: () => _runFriendAction(friend.id, widget.onBlockFriend, 'Đã chặn bạn bè'),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (canToggle)
                        _ExpandToggle(
                          isExpanded: _isExpanded,
                          onPressed: () => setState(() => _isExpanded = !_isExpanded),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;

  const _SearchBox({required this.controller, required this.isSearching});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: TextField(
        key: const ValueKey('friend-search-field'),
        controller: controller,
        textInputAction: TextInputAction.search,
        cursorColor: Colors.white,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: 'Thêm một người bạn mới',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          prefixIcon: Icon(LucideIcons.search, color: Colors.white.withValues(alpha: 0.86), size: 28),
          suffixIcon: isSearching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF353535),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.82), size: 28),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  final FriendProfile friend;
  final Key actionKey;
  final bool isBusy;
  final bool isMenuOpen;
  final VoidCallback onOpenActions;
  final VoidCallback onHide;
  final VoidCallback onUnfriend;
  final VoidCallback onBlock;

  const _FriendRow({
    required this.friend,
    required this.actionKey,
    required this.isBusy,
    required this.isMenuOpen,
    required this.onOpenActions,
    required this.onHide,
    required this.onUnfriend,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _FriendAvatar(profile: friend),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                friend.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              key: actionKey,
              onPressed: isBusy ? null : onOpenActions,
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 34),
              tooltip: 'Tùy chọn bạn bè',
            ),
          ],
        ),
        if (isMenuOpen)
          Align(
            alignment: Alignment.centerRight,
            child: _FriendActionPopup(
              onHide: onHide,
              onUnfriend: onUnfriend,
              onBlock: onBlock,
            ),
          ),
      ],
    );
  }
}

class _FriendActionPopup extends StatelessWidget {
  final VoidCallback onHide;
  final VoidCallback onUnfriend;
  final VoidCallback onBlock;

  const _FriendActionPopup({
    required this.onHide,
    required this.onUnfriend,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(top: 8, right: 6),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FriendActionButton(icon: LucideIcons.eyeOff, label: 'Ẩn bạn bè', onPressed: onHide),
          _FriendActionButton(icon: LucideIcons.userX, label: 'Xóa bạn', onPressed: onUnfriend),
          _FriendActionButton(
            icon: LucideIcons.circleOff,
            label: 'Chặn bạn bè',
            color: const Color(0xFFFF5A66),
            onPressed: onBlock,
          ),
        ],
      ),
    );
  }
}

class _FriendActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _FriendActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: 25),
      label: Text(
        label,
        style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.w800),
      ),
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 28),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  final FriendSearchResult result;
  final bool isBusy;
  final VoidCallback? onAdd;

  const _SearchResultRow({required this.result, required this.isBusy, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _FriendAvatar(profile: result.profile, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                ),
                if (result.profile.handle.isNotEmpty)
                  Text(
                    '@${result.profile.handle}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.56), fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            key: ValueKey('friend-add-${result.profile.id}'),
            onPressed: isBusy ? null : onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: onAdd == null ? const Color(0xFF575757) : const Color(0xFFFFC400),
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFF575757),
              disabledForegroundColor: Colors.white70,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: Text(onAdd == null ? _statusLabel(result.relationStatus) : 'Thêm'),
          ),
        ],
      ),
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

class _FriendAvatar extends StatelessWidget {
  final FriendProfile profile;
  final double size;

  const _FriendAvatar({required this.profile, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: Color(0xFFFFC400), shape: BoxShape.circle),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF393939),
        backgroundImage: profile.avatarUrl == null ? null : NetworkImage(profile.avatarUrl!),
        child: profile.avatarUrl == null
            ? Text(
                profile.initials,
                style: TextStyle(color: Colors.white, fontSize: size * 0.26, fontWeight: FontWeight.w900),
              )
            : null,
      ),
    );
  }
}

class _ExpandToggle extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onPressed;

  const _ExpandToggle({required this.isExpanded, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.08), thickness: 2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF3A3A3A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            child: Text(
              isExpanded ? 'Rút gọn' : 'Xem thêm',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.08), thickness: 2)),
      ],
    );
  }
}

class _FriendListSkeleton extends StatelessWidget {
  const _FriendListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            children: [
              Container(width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFF343434), shape: BoxShape.circle)),
              const SizedBox(width: 18),
              Expanded(
                child: Container(height: 22, decoration: BoxDecoration(color: const Color(0xFF343434), borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFriendsState extends StatelessWidget {
  const _EmptyFriendsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        'Chưa có bạn bè nào',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.64), fontSize: 17, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final String message;

  const _InlineMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        message,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }
}
