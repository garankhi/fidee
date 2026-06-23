import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/comment_provider.dart';
import '../services/comment_service.dart';

class CommentSheet extends ConsumerStatefulWidget {
  final String targetType;
  final String targetId;
  final int initialCommentCount;

  const CommentSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.initialCommentCount = 0,
  });

  @override
  ConsumerState<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<CommentSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;

  String get _targetKey => '${widget.targetType}:${widget.targetId}';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);

    Future.microtask(() async {
      final authService = ref.read(authServiceProvider);
      final currentUserId = await authService.getCurrentUserSub();
      if (mounted) {
        setState(() {
          _currentUserId = currentUserId;
        });
      }
      await ref
          .read(commentControllerProvider(_targetKey).notifier)
          .loadComments();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(commentControllerProvider(_targetKey).notifier).loadMore();
    }
  }

  Future<void> _submit() async {
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    await ref
        .read(commentControllerProvider(_targetKey).notifier)
        .addComment(content);
    if (!mounted) return;
    _textController.clear();
  }

  int _visibleCount(CommentState state) {
    if (state.comments.isEmpty) return widget.initialCommentCount;
    return state.comments.fold<int>(
      0,
      (total, comment) => total + 1 + comment.replyCount,
    );
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime.toLocal());
    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inHours < 1) return '${difference.inMinutes} phút';
    if (difference.inDays < 1) return '${difference.inHours} giờ';
    if (difference.inDays < 7) return '${difference.inDays} ngày';
    return DateFormat('dd/MM/yyyy').format(dateTime.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commentControllerProvider(_targetKey));
    final notifier = ref.read(commentControllerProvider(_targetKey).notifier);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Bình luận',
                      style: TextStyle(
                        color: Color(0xFF0E1B16),
                        fontFamily: 'SF Pro',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8EA),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _visibleCount(state).toString(),
                        style: const TextStyle(
                          color: Color(0xFFEF484F),
                          fontFamily: 'SF Pro',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEFEFEF)),
              Expanded(child: _buildBody(state, notifier)),
              _buildInputBar(state, notifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(CommentState state, CommentController notifier) {
    if (state.isLoading && state.comments.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        itemCount: 5,
        itemBuilder: (_, __) => const _CommentSkeleton(),
      );
    }

    if (state.comments.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có bình luận',
          style: TextStyle(
            color: Color(0xFF707070),
            fontFamily: 'SF Pro',
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      itemCount: state.comments.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.comments.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: _CommentSkeleton(),
          );
        }

        final comment = state.comments[index];
        return _CommentThread(
          comment: comment,
          currentUserId: _currentUserId,
          onReply: notifier.setReplyingTo,
          onDelete: notifier.deleteComment,
          onLoadReplies: notifier.loadAllReplies,
          timeAgo: _timeAgo,
        );
      },
    );
  }

  Widget _buildInputBar(CommentState state, CommentController notifier) {
    final replyingTo = state.replyingTo;
    final replyName = replyingTo?.userUsername?.isNotEmpty == true
        ? replyingTo!.userUsername!
        : replyingTo?.userName;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEFEFEF))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyingTo != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Đang phản hồi @$replyName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFEF484F),
                          fontFamily: 'SF Pro',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: notifier.clearReplyingTo,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: replyingTo == null
                          ? 'Viết bình luận...'
                          : 'Viết phản hồi...',
                      filled: true,
                      fillColor: const Color(0xFFF6F6F6),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEF484F),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: state.isSubmitting ? null : _submit,
                  icon: const Icon(Icons.send_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentThread extends StatelessWidget {
  final Comment comment;
  final String? currentUserId;
  final void Function(Comment comment) onReply;
  final Future<void> Function(String commentId) onDelete;
  final Future<void> Function(String commentId) onLoadReplies;
  final String Function(DateTime createdAt) timeAgo;

  const _CommentThread({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onDelete,
    required this.onLoadReplies,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final hiddenReplyCount = comment.replyCount - comment.replies.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentTile(
            comment: comment,
            currentUserId: currentUserId,
            onReply: onReply,
            onDelete: onDelete,
            timeAgo: timeAgo,
          ),
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 10),
              child: Column(
                children: [
                  for (final reply in comment.replies)
                    _CommentTile(
                      comment: reply,
                      currentUserId: currentUserId,
                      onReply: onReply,
                      onDelete: onDelete,
                      timeAgo: timeAgo,
                      isReply: true,
                    ),
                ],
              ),
            ),
          if (hiddenReplyCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 4),
              child: TextButton(
                onPressed: () => onLoadReplies(comment.id),
                child: Text('Xem thêm $hiddenReplyCount phản hồi'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final String? currentUserId;
  final bool isReply;
  final void Function(Comment comment) onReply;
  final Future<void> Function(String commentId) onDelete;
  final String Function(DateTime createdAt) timeAgo;

  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onDelete,
    required this.timeAgo,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    final canDelete = currentUserId != null && currentUserId == comment.userId;
    final avatar = comment.userAvatar;
    final username = comment.userUsername?.isNotEmpty == true
        ? '@${comment.userUsername}'
        : null;
    final replyTo = comment.replyToUserName;

    final child = Padding(
      padding: EdgeInsets.only(bottom: isReply ? 10 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 15 : 17,
            backgroundColor: const Color(0xFFF0F0F0),
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? NetworkImage(avatar)
                : null,
            child: avatar == null || avatar.isEmpty
                ? const Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: Color(0xFF8A8A8A),
                  )
                : null,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                comment.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF0E1B16),
                                  fontFamily: 'SF Pro',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (username != null) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF8A8A8A),
                                    fontFamily: 'SF Pro',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              if (replyTo != null && replyTo.isNotEmpty)
                                TextSpan(
                                  text: '@$replyTo ',
                                  style: const TextStyle(
                                    color: Color(0xFFEF484F),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              TextSpan(text: comment.content),
                            ],
                          ),
                          style: const TextStyle(
                            color: Color(0xFF0E1B16),
                            fontFamily: 'SF Pro',
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 5),
                  child: Row(
                    children: [
                      Text(
                        timeAgo(comment.createdAt),
                        style: const TextStyle(
                          color: Color(0xFF8A8A8A),
                          fontFamily: 'SF Pro',
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 14),
                      InkWell(
                        onTap: () => onReply(comment),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          child: Text(
                            'Phản hồi',
                            style: TextStyle(
                              color: Color(0xFF5F5F5F),
                              fontFamily: 'SF Pro',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!canDelete) return child;

    return Dismissible(
      key: ValueKey(comment.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFEF484F),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await onDelete(comment.id);
        return false;
      },
      child: child,
    );
  }
}

class _CommentSkeleton extends StatelessWidget {
  const _CommentSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 17, backgroundColor: Color(0xFFEDEDED)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  width: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEDED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
