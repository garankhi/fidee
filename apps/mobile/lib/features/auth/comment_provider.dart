import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../services/comment_service.dart';
import 'auth_providers.dart';

part 'comment_provider.g.dart';

class CommentState {
  final List<Comment> comments;
  final bool isLoading;
  final bool isSubmitting;
  final bool hasMore;
  final String? nextCursor;
  final String? error;
  final Comment? replyingTo;

  const CommentState({
    this.comments = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.hasMore = false,
    this.nextCursor,
    this.error,
    this.replyingTo,
  });

  CommentState copyWith({
    List<Comment>? comments,
    bool? isLoading,
    bool? isSubmitting,
    bool? hasMore,
    String? nextCursor,
    String? error,
    Comment? replyingTo,
    bool clearError = false,
    bool clearReplyingTo = false,
    bool clearCursor = false,
  }) {
    return CommentState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      error: clearError ? null : (error ?? this.error),
      replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
    );
  }
}

@riverpod
class CommentController extends _$CommentController {
  late final String _targetType;
  late final String _targetId;

  @override
  CommentState build(String targetKey) {
    final parts = targetKey.split(':');
    _targetType = parts[0];
    _targetId = parts.sublist(1).join(':');
    return const CommentState();
  }

  CommentService _service() {
    final authService = ref.read(authServiceProvider);
    return CommentService(authService);
  }

  Future<void> loadComments() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final page = await _service().getComments(
        targetType: _targetType,
        targetId: _targetId,
      );
      state = state.copyWith(
        comments: page.comments,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        isLoading: false,
        clearCursor: page.nextCursor == null,
      );
    } catch (error) {
      debugPrint('loadComments error: $error');
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final page = await _service().getComments(
        targetType: _targetType,
        targetId: _targetId,
        cursor: state.nextCursor,
      );
      state = state.copyWith(
        comments: [...state.comments, ...page.comments],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        isLoading: false,
        clearCursor: page.nextCursor == null,
      );
    } catch (error) {
      debugPrint('loadMore error: $error');
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> addComment(String content) async {
    if (content.trim().isEmpty) return;

    state = state.copyWith(isSubmitting: true, clearError: true);

    final replyingTo = state.replyingTo;
    final requestedParentId = replyingTo?.id;
    final rootParentId = replyingTo?.parentId ?? replyingTo?.id;

    try {
      final newComment = await _service().createComment(
        targetType: _targetType,
        targetId: _targetId,
        content: content.trim(),
        parentId: requestedParentId,
      );

      if (newComment != null) {
        if (rootParentId != null) {
          // It's a reply — add to the parent's replies list
          final updated = state.comments.map((c) {
            if (c.id == rootParentId) {
              return c.copyWith(
                replies: [...c.replies, newComment],
                replyCount: c.replyCount + 1,
              );
            }
            return c;
          }).toList();
          state = state.copyWith(
            comments: updated,
            isSubmitting: false,
            clearReplyingTo: true,
          );
        } else {
          // Top-level comment — prepend to list
          state = state.copyWith(
            comments: [newComment, ...state.comments],
            isSubmitting: false,
            clearReplyingTo: true,
          );
        }
      } else {
        state = state.copyWith(isSubmitting: false);
      }
    } catch (error) {
      debugPrint('addComment error: $error');
      state = state.copyWith(isSubmitting: false, error: error.toString());
    }
  }

  Future<void> deleteComment(String commentId) async {
    final success = await _service().deleteComment(commentId);

    if (success) {
      // Check if it's a top-level comment
      final isTopLevel = state.comments.any((c) => c.id == commentId);
      if (isTopLevel) {
        state = state.copyWith(
          comments: state.comments.where((c) => c.id != commentId).toList(),
        );
      } else {
        // It's a reply — remove from parent's replies
        final updated = state.comments.map((c) {
          if (c.replies.any((r) => r.id == commentId)) {
            return c.copyWith(
              replies: c.replies.where((r) => r.id != commentId).toList(),
              replyCount: (c.replyCount - 1).clamp(0, c.replyCount),
            );
          }
          return c;
        }).toList();
        state = state.copyWith(comments: updated);
      }
    }
  }

  Future<void> loadAllReplies(String commentId) async {
    try {
      final page = await _service().getReplies(commentId: commentId);

      final updated = state.comments.map((c) {
        if (c.id == commentId) {
          return c.copyWith(replies: page.comments);
        }
        return c;
      }).toList();
      state = state.copyWith(comments: updated);
    } catch (error) {
      debugPrint('loadAllReplies error: $error');
    }
  }

  void setReplyingTo(Comment? comment) {
    if (comment == null) {
      state = state.copyWith(clearReplyingTo: true);
    } else {
      state = state.copyWith(replyingTo: comment);
    }
  }

  void clearReplyingTo() {
    state = state.copyWith(clearReplyingTo: true);
  }
}
