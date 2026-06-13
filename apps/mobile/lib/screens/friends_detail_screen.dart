import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/chat_provider.dart';
import '../features/auth/friends_provider.dart';
import '../features/friends/widgets/friend_request_widgets.dart';
import '../features/friends/widgets/friend_search_result_action_row.dart';
import '../services/friend_service.dart';
import 'chat_thread_screen.dart';

class FriendsDetailScreen extends ConsumerStatefulWidget {
  const FriendsDetailScreen({super.key});

  @override
  ConsumerState<FriendsDetailScreen> createState() =>
      _FriendsDetailScreenState();
}

class _FriendsDetailScreenState extends ConsumerState<FriendsDetailScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _busyRequestId;
  String? _busySearchResultId;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final nextQuery = _searchCtrl.text.trim().toLowerCase();
      setState(() {
        _searchQuery = nextQuery;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép liên kết vào bộ nhớ tạm!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareLink(String text, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tính năng Chia sẻ hệ thống đang được kích hoạt!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _runRequestAction(
    String userId,
    Future<bool> Function(String userId) action,
    String successMessage,
  ) async {
    setState(() => _busyRequestId = userId);
    final success = await action(userId);
    if (!mounted) return;
    setState(() => _busyRequestId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? successMessage : 'Không thực hiện được. Vui lòng thử lại.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _runSearchResultAction(
    FriendSearchResult result,
    Future<bool> Function(String userId) action,
    String successMessage,
  ) async {
    setState(() => _busySearchResultId = result.profile.id);
    final success = await action(result.profile.id);
    if (!mounted) return;
    setState(() {
      _busySearchResultId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? successMessage : 'Không thực hiện được. Vui lòng thử lại.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openChat(FriendProfile friend) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final conversationId = await ref
        .read(chatInboxControllerProvider.notifier)
        .openDirectConversation(friend.id);
    if (!mounted) return;
    if (conversationId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không mở được cuộc trò chuyện. Vui lòng thử lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => ChatThreadScreen(
          conversationId: conversationId,
          friendName: friend.name,
          avatarUrl: friend.avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final friendsState = ref.watch(friendsControllerProvider);
    final friendsNotifier = ref.read(friendsControllerProvider.notifier);

    final preferredUsername = authService.preferredUsername ?? 'user';
    final shareText =
        'Xin chào! Kết bạn với mình trên FIDEE nha. https://fidee.site/$preferredUsername';

    // Filter friends list dynamically based on search query
    final filteredFriends = friendsState.friends.where((friend) {
      if (friend.id == friendsState.currentUserId) return false;
      if (_searchQuery.isEmpty) return true;
      return friend.name.toLowerCase().contains(_searchQuery) ||
          friend.handle.toLowerCase().contains(_searchQuery);
    }).toList();
    final visibleFriendCount = friendsState.friends
        .where((friend) => friend.id != friendsState.currentUserId)
        .length;

    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFFEF4050),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black54),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leadingWidth: 70,
          leading: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE9EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Color(0xFFEF4050),
                  size: 16,
                ),
              ),
            ),
          ),
          title: const Text(
            'FRIENDS',
            style: TextStyle(
              color: Color(0xFFEF4050),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              fontFamily: 'SF Pro',
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // 1. Search Bar Top
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 22.0,
                vertical: 12.0,
              ),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(23),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      color: Color(0xFF8E8E93),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Tìm kiếm bạn bè...',
                          hintStyle: TextStyle(
                            color: Color(0xFFEF484F),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: const TextStyle(
                          color: Color(0xFFEF484F),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFF8E8E93),
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 2. Share FIDEE Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(
                            0xFFEF4050,
                          ).withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Chia sẻ FIDEE của bạn?',
                            style: TextStyle(
                              color: Color(0xFF151515),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Mời bạn bè cùng tham gia khám phá & check-in',
                            style: TextStyle(
                              color: Color(0xFF6E7E91),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(
                                  0xFFEF4050,
                                ).withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              shareText,
                              style: const TextStyle(
                                color: Color(0xFFEF4050),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _copyToClipboard(shareText, context),
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Sao chép'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF6E7E91),
                                      side: const BorderSide(
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _shareLink(shareText, context),
                                    icon: const Icon(Icons.share, size: 16),
                                    label: const Text('Chia sẻ'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4050),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 3. Pending Friend Requests (Lời mời kết bạn)
                    if (friendsState.requests.isNotEmpty) ...[
                      const Text(
                        'Lời mời kết bạn',
                        style: TextStyle(
                          color: Color(0xFF151515),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: friendsState.requests.length,
                        itemBuilder: (context, index) {
                          final req = friendsState.requests[index];

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: FriendRequestActionRow(
                              request: req,
                              tone: FriendRequestTone.light,
                              isBusy: _busyRequestId == req.id,
                              onAccept: () => _runRequestAction(
                                req.id,
                                friendsNotifier.accept,
                                'Đã chấp nhận lời mời',
                              ),
                              onDecline: () => _runRequestAction(
                                req.id,
                                friendsNotifier.decline,
                                'Đã từ chối lời mời',
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                    ],

                    if (friendsState.sentRequests.isNotEmpty) ...[
                      const Text(
                        'Lời mời đã gửi',
                        style: TextStyle(
                          color: Color(0xFF151515),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final sentRequest in friendsState.sentRequests)
                        FriendSearchResultActionRow(
                          result: FriendSearchResult(
                            profile: sentRequest,
                            relationStatus: FriendRelationStatus.pending,
                            relationDirection: FriendRelationDirection.outgoing,
                            canRequest: false,
                            canCancelRequest: true,
                            canAcceptRequest: false,
                          ),
                          tone: FriendRequestTone.light,
                          isBusy: _busySearchResultId == sentRequest.id,
                          onCancel: () => _runSearchResultAction(
                            FriendSearchResult(
                              profile: sentRequest,
                              relationStatus: FriendRelationStatus.pending,
                              relationDirection:
                                  FriendRelationDirection.outgoing,
                              canRequest: false,
                              canCancelRequest: true,
                              canAcceptRequest: false,
                            ),
                            friendsNotifier.cancelFriendRequest,
                            'Đã hủy lời mời kết bạn',
                          ),
                        ),
                      const SizedBox(height: 28),
                    ],

                    // 4. Friend List (Danh sách bạn bè)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Danh sách bạn bè',
                          style: TextStyle(
                            color: Color(0xFF151515),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$visibleFriendCount người bạn',
                          style: const TextStyle(
                            color: Color(0xFF8D8D8D),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    friendsState.isInitialLoading
                        ? const _FriendsDetailListSkeleton()
                        : filteredFriends.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 32.0,
                              ),
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'Chưa có bạn bè trong danh sách.'
                                    : 'Không tìm thấy kết quả phù hợp.',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredFriends.length,
                            itemBuilder: (context, index) {
                              final friend = filteredFriends[index];

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFFFD4DA),
                                        image:
                                            friend.avatarUrl != null &&
                                                friend.avatarUrl!.isNotEmpty
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                  friend.avatarUrl!,
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child:
                                          friend.avatarUrl == null ||
                                              friend.avatarUrl!.isEmpty
                                          ? Center(
                                              child: Text(
                                                friend.initials,
                                                style: const TextStyle(
                                                  color: Color(0xFFEF4050),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            friend.name,
                                            style: const TextStyle(
                                              color: Color(0xFF151515),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '@${friend.handle}',
                                            style: const TextStyle(
                                              color: Color(0xFF8D8D8D),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () =>
                                          unawaited(_openChat(friend)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFEF4050,
                                        ),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Nhắn tin',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        // Show confirm dialog
                                        showDialog<void>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Hủy kết bạn?'),
                                            content: Text(
                                              'Bạn có chắc chắn muốn hủy kết bạn với ${friend.name}?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: const Text(
                                                  'Hủy',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  friendsNotifier.unfriend(
                                                    friend.id,
                                                  );
                                                },
                                                child: const Text(
                                                  'Xác nhận',
                                                  style: TextStyle(
                                                    color: Color(0xFFEF4050),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFFECEF,
                                        ),
                                        foregroundColor: const Color(
                                          0xFFEF4050,
                                        ),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Hủy kết bạn',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsDetailListSkeleton extends StatelessWidget {
  const _FriendsDetailListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD4DA),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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
