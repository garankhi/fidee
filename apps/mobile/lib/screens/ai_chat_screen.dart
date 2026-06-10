import 'package:flutter/material.dart';

class AiChatScreen extends StatefulWidget {
  final String? initialMessage;

  const AiChatScreen({super.key, this.initialMessage});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _chatController = TextEditingController();
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    final initialMessage = widget.initialMessage?.trim();
    if (initialMessage != null && initialMessage.isNotEmpty) {
      _messages.add(initialMessage);
    }
  }

  void _sendMessage(String value) {
    final message = value.trim();
    if (message.isEmpty) return;
    setState(() => _messages.add(message));
    _chatController.clear();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF8888),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _MaviHeader(onBack: () => Navigator.pop(context)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      const _MessageBubble(
                        text:
                            'Chào bạn! Mình là Mavi. Hãy kể về món bạn đang thèm, ngân sách hoặc vibe hôm nay nhé.',
                      ),
                      const SizedBox(height: 16),
                      _SuggestionButton(
                        label: 'Tìm 3 nhà hàng gần tôi',
                        onTap: () => _sendMessage('Tìm 3 nhà hàng gần tôi'),
                      ),
                      const SizedBox(height: 16),
                      const _RecommendationCard(),
                      if (_messages.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        for (final message in _messages) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: _MessageBubble(
                              text: message,
                              isUser: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const _MessageBubble(
                            text:
                                'Mavi đã nhận vibe của bạn và đang lọc địa điểm phù hợp hơn.',
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _QuickOptionChip(
                            label: 'Không cay',
                            onTap: () => _sendMessage('Chỉ món không cay'),
                          ),
                          _QuickOptionChip(
                            label: 'Lãng mạn và yên tĩnh',
                            onTap: () =>
                                _sendMessage('Lãng mạn và yên tĩnh hơn'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _ChatInput(
                controller: _chatController,
                onSend: () => _sendMessage(_chatController.text),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaviHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _MaviHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white24,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        const CircleAvatar(
          radius: 26,
          backgroundColor: Color(0xFFEF4050),
          child: Text(
            'M',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mavi AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text('Online', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _MessageBubble({required this.text, this.isUser = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isUser ? null : double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFEF4050) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isUser ? Colors.white : Colors.black87,
          height: 1.4,
        ),
      ),
    );
  }
}

class _SuggestionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFEF4050),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gợi ý hợp vibe của bạn',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          SizedBox(height: 14),
          _RecommendedPlaceItem(index: 1, name: 'The Garden', distance: '0.5 km'),
          SizedBox(height: 12),
          _RecommendedPlaceItem(
            index: 2,
            name: 'Moonlight Ramen',
            distance: '0.7 km',
          ),
          SizedBox(height: 12),
          _RecommendedPlaceItem(
            index: 3,
            name: 'B2Q Saigon',
            distance: '0.9 km',
          ),
        ],
      ),
    );
  }
}

class _RecommendedPlaceItem extends StatelessWidget {
  final int index;
  final String name;
  final String distance;

  const _RecommendedPlaceItem({
    required this.index,
    required this.name,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$index.', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Text(distance, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _QuickOptionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickOptionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: Colors.white,
      label: Text(label),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _ChatInput({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5A5A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Hôm nay bạn muốn vibe thế nào?',
                hintStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ),
          IconButton.filled(
            onPressed: onSend,
            style: IconButton.styleFrom(backgroundColor: Colors.white),
            icon: const Icon(Icons.send_rounded, color: Color(0xFFEF4050)),
          ),
        ],
      ),
    );
  }
}
