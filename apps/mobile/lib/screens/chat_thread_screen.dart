import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/chat_provider.dart';
import '../services/appsync_realtime_service.dart';
import '../services/user_chat_service.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String friendName;
  final String? avatarUrl;

  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    required this.friendName,
    this.avatarUrl,
  });

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _controller = TextEditingController();
  Timer? _typingDebounce;

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    _controller.clear();
    await ref
        .read(chatThreadControllerProvider(widget.conversationId).notifier)
        .send(text);
  }

  void _onTypingChanged(String value) {
    final notifier = ref.read(
      chatThreadControllerProvider(widget.conversationId).notifier,
    );
    unawaited(notifier.sendTyping(value.trim().isNotEmpty));
    _typingDebounce?.cancel();
    _typingDebounce = Timer(
      const Duration(seconds: 3),
      () => unawaited(notifier.sendTyping(false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      chatThreadControllerProvider(widget.conversationId),
    );
    final authService = ref.watch(authServiceProvider);
    ref.listen<ChatRealtimeEvent?>(lastChatRealtimeEventProvider, (
      previous,
      next,
    ) {
      if (next == null || next.conversationId != widget.conversationId) return;
      ref
          .read(chatThreadControllerProvider(widget.conversationId).notifier)
          .applyRealtimeEvent(next);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF101B1F),
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(name: widget.friendName, avatarUrl: widget.avatarUrl),
            Expanded(
              child: state.isLoading && state.messages.isEmpty
                  ? const _MessageSkeleton()
                  : FutureBuilder<String?>(
                      future: authService.getCurrentUserSub(),
                      builder: (context, snapshot) {
                        final currentUserId = snapshot.data;
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                          itemCount:
                              state.messages.length + (state.isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= state.messages.length) {
                              return const _TypingBubble();
                            }
                            final message = state.messages[index];
                            return _MessageBubble(
                              message: message,
                              isMine: message.senderId == currentUserId,
                            );
                          },
                        );
                      },
                    ),
            ),
            _Composer(
              controller: _controller,
              onChanged: _onTypingChanged,
              onSend: () => unawaited(_send()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _ChatHeader({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          CircleAvatar(
            backgroundColor: const Color(0xFF303E42),
            backgroundImage: avatarUrl == null
                ? null
                : NetworkImage(avatarUrl!),
            child: avatarUrl == null
                ? Text(
                    name.trim().isEmpty ? '?' : name.characters.first,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final UserChatMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFEF4050) : const Color(0xFF243135),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            if (message.isPending) ...[
              const SizedBox(height: 4),
              Text(
                'Đang gửi',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF243135),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'Đang nhập...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF243135),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Nhắn tin...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, color: Color(0xFFEF4050)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageSkeleton extends StatelessWidget {
  const _MessageSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: 8,
      itemBuilder: (context, index) => Align(
        alignment: index.isEven ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          width: index.isEven ? 220 : 180,
          height: 42,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
