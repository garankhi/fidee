import 'package:flutter/material.dart';

import '../widgets/glass_surface.dart';

class CameraFeedMessageComposer extends StatefulWidget {
  final ValueChanged<String>? onSend;
  final ValueChanged<String>? onReaction;

  const CameraFeedMessageComposer({super.key, this.onSend, this.onReaction});

  @override
  State<CameraFeedMessageComposer> createState() =>
      _CameraFeedMessageComposerState();
}

class _CameraFeedMessageComposerState extends State<CameraFeedMessageComposer> {
  final TextEditingController _controller = TextEditingController();

  void _submitMessage() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    widget.onSend?.call(message);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      key: const ValueKey('camera-feed-message-composer'),
      borderRadius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      tint: const Color(0x2EFFFFFF),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('camera-feed-message-field'),
              controller: _controller,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitMessage(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Gửi tin nhắn...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _ReactionButton(
            label: '🏅',
            onTap: () => widget.onReaction?.call('🏅'),
          ),
          _ReactionButton(
            label: '🎾',
            onTap: () => widget.onReaction?.call('🎾'),
          ),
          _ReactionButton(
            label: '😋',
            onTap: () => widget.onReaction?.call('😋'),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.add_reaction_outlined,
              color: Colors.white,
              size: 30,
            ),
            tooltip: 'Thêm cảm xúc',
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ReactionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Text(label, style: const TextStyle(fontSize: 26)),
      tooltip: label,
    );
  }
}
