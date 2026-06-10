import 'package:flutter/material.dart';

import 'camera_bottom_section.dart';

class CameraChatThread {
  final String id;
  final String name;
  final String lastMessage;
  final String updatedAtLabel;
  final String? avatarUrl;

  const CameraChatThread({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.updatedAtLabel,
    this.avatarUrl,
  });

  CameraChatThread copyWith({
    String? lastMessage,
    String? updatedAtLabel,
    String? avatarUrl,
  }) {
    return CameraChatThread(
      id: id,
      name: name,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class CameraChatInboxScreen extends StatelessWidget {
  final List<CameraChatThread> threads;

  const CameraChatInboxScreen({super.key, required this.threads});

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
                  child: threads.isEmpty
                      ? const _CameraChatEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(28, 26, 24, 130),
                          itemBuilder: (context, index) {
                            return _CameraChatThreadRow(thread: threads[index]);
                          },
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 30),
                          itemCount: threads.length,
                        ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: CameraBottomSection(
                onHomeTap: () => Navigator.pop(context),
                onChatTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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

  const _CameraChatThreadRow({required this.thread});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: ValueKey('camera-chat-thread-${thread.id}'),
      children: [
        _ThreadAvatar(thread: thread),
        const SizedBox(width: 18),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    thread.updatedAtLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.44),
                      fontSize: 22,
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
                  fontSize: 22,
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
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF243135),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 4),
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF303E42),
        backgroundImage: thread.avatarUrl == null ? null : NetworkImage(thread.avatarUrl!),
        child: thread.avatarUrl == null
            ? Text(
                initial,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              )
            : null,
      ),
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
