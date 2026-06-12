import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/chat_provider.dart';
import '../services/user_chat_service.dart';
import 'camera_bottom_section.dart';
import 'chat_thread_screen.dart';

class CameraChatThread {
  final String id;
  final String? conversationId;
  final String name;
  final String lastMessage;
  final String updatedAtLabel;
  final String? avatarUrl;

  const CameraChatThread({
    required this.id,
    this.conversationId,
    required this.name,
    required this.lastMessage,
    required this.updatedAtLabel,
    this.avatarUrl,
  });

  factory CameraChatThread.fromConversation(UserChatConversation conversation) {
    return CameraChatThread(
      id: conversation.otherUser.id,
      conversationId: conversation.id,
      name: conversation.otherUser.name,
      lastMessage: conversation.lastMessage?.body ?? 'Bắt đầu trò chuyện',
      updatedAtLabel: _relativeTimeLabel(conversation.updatedAt),
      avatarUrl: conversation.otherUser.avatarUrl,
    );
  }

  CameraChatThread copyWith({
    String? lastMessage,
    String? updatedAtLabel,
    String? avatarUrl,
  }) {
    return CameraChatThread(
      id: id,
      conversationId: conversationId,
      name: name,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class CameraChatInboxScreen extends StatelessWidget {
  final List<CameraChatThread>? threads;

  const CameraChatInboxScreen({super.key, this.threads});

  @override
  Widget build(BuildContext context) {
    final localThreads = threads;
    if (localThreads != null) {
      return _CameraChatInboxScaffold(
        threadRows: localThreads,
        isLoading: false,
      );
    }

    return Consumer(
      builder: (context, ref, child) {
        final inboxState = ref.watch(chatInboxControllerProvider);
        return _CameraChatInboxScaffold(
          threadRows: inboxState.conversations
              .map(CameraChatThread.fromConversation)
              .toList(growable: false),
          isLoading: inboxState.isLoading,
        );
      },
    );
  }
}

class _CameraChatInboxScaffold extends StatelessWidget {
  final List<CameraChatThread> threadRows;
  final bool isLoading;

  const _CameraChatInboxScaffold({
    required this.threadRows,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101B1F),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const _CameraChatHeader(),
                Expanded(
                  child: isLoading && threadRows.isEmpty
                      ? const _CameraChatInboxSkeleton()
                      : threadRows.isEmpty
                      ? const _CameraChatEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(28, 26, 24, 130),
                          itemBuilder: (context, index) {
                            final thread = threadRows[index];
                            return _CameraChatThreadRow(
                              thread: thread,
                              onTap: thread.conversationId == null
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) => ChatThreadScreen(
                                          conversationId:
                                              thread.conversationId!,
                                          friendName: thread.name,
                                          avatarUrl: thread.avatarUrl,
                                        ),
                                      ),
                                    ),
                            );
                          },
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 30),
                          itemCount: threadRows.length,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTimeLabel(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'vừa xong';
  if (diff.inHours < 1) return '${diff.inMinutes} phút';
  if (diff.inDays < 1) return '${diff.inHours} giờ';
  return '${diff.inDays} ngày';
}

class _CameraChatHeader extends StatelessWidget {
  const _CameraChatHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'Trò chuyện',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'Me',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraChatThreadRow extends StatelessWidget {
  final CameraChatThread thread;
  final VoidCallback? onTap;

  const _CameraChatThreadRow({required this.thread, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        key: ValueKey('camera-chat-thread-${thread.id}'),
        children: [
          _ThreadAvatar(thread: thread),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        thread.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      thread.updatedAtLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.44),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  thread.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.58),
            size: 38,
          ),
        ],
      ),
    );
  }
}

class _ThreadAvatar extends StatelessWidget {
  final CameraChatThread thread;

  const _ThreadAvatar({required this.thread});

  @override
  Widget build(BuildContext context) {
    final initial = thread.name.trim().isEmpty
        ? '?'
        : thread.name.trim().characters.first.toUpperCase();

    return Container(
      width: 60,
      height: 60,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF243135),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 4,
        ),
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF303E42),
        backgroundImage: thread.avatarUrl == null
            ? null
            : NetworkImage(thread.avatarUrl!),
        child: thread.avatarUrl == null
            ? Text(
                initial,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              )
            : null,
      ),
    );
  }
}

class _CameraChatInboxSkeleton extends StatelessWidget {
  const _CameraChatInboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(28, 26, 24, 130),
      itemBuilder: (context, index) => Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF243135),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 22,
                  width: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 18,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      separatorBuilder: (context, index) => const SizedBox(height: 30),
      itemCount: 5,
    );
  }
}

class _CameraChatEmptyState extends StatelessWidget {
  const _CameraChatEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Chưa có tin nhắn',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.68),
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
