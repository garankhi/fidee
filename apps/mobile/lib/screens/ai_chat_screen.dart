import 'package:flutter/material.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}

class _Recommendation {
  final String name;
  final String category;
  final String distance;
  final String duration;
  final String rating;
  final List<String> tags;

  const _Recommendation({
    required this.name,
    required this.category,
    required this.distance,
    required this.duration,
    required this.rating,
    required this.tags,
  });
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _chatController = TextEditingController();
  final List<_ChatMessage> _messages = [];

  static const List<_Recommendation> _recommendations = [
    _Recommendation(
      name: 'Sân Vườn Cafe',
      category: 'Cafe',
      distance: '0,3 km',
      duration: '5-7 phút',
      rating: '4.8',
      tags: ['Yên tĩnh', 'Đẹp mắt', 'Phù hợp học/làm việc'],
    ),
    _Recommendation(
      name: 'Ramen Ánh Trăng',
      category: 'Món Nhật',
      distance: '0,8 km',
      duration: '5-7 phút',
      rating: '4.8',
      tags: ['Ấm cúng', 'Lãng mạn', 'Yên tĩnh'],
    ),
    _Recommendation(
      name: 'Bún Chả Góc Phố',
      category: 'Món Việt',
      distance: '0,5 km',
      duration: '6-8 phút',
      rating: '4.8',
      tags: ['Đậm vị địa phương', 'Nhanh gọn', 'Dễ ăn'],
    ),
  ];

  void _sendMessage(String message) {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: trimmedMessage, isUser: true));
      _messages.add(
        const _ChatMessage(
          text:
              'Fidee đã nhận vibe của bạn. Mình sẽ tiếp tục lọc các địa điểm phù hợp hơn cho bạn.',
          isUser: false,
        ),
      );
    });
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // === Header: Back Button & Title ===
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // === Mavi AI Header ===
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4050),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'M',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mavi AI',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '⚡',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF22C55E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // === Mavi AI Intro Message ===
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hey! I\'m Mavi, your vibe guide. Tell me what you\'re feeling—cravings, budget, location, type—and I\'ll find the perfect spots just for you.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // === Quick Suggestion Button ===
              GestureDetector(
                onTap: () => _sendMessage('Hey! Find 3 restaurants near me 🍔'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4050),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Center(
                    child: Text(
                      'Hey! Find 3 restaurants near me 🍔',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // === Mavi AI Response ===
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Smart search, analyzing your vibe with 💖',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _RecommendedPlaceItem(
                      index: 1,
                      name: 'The Garden',
                      tags: ['Nhà hàng', 'Cafe', 'Thoải mái'],
                      distance: '0.5 km',
                    ),
                    const SizedBox(height: 14),
                    const _RecommendedPlaceItem(
                      index: 2,
                      name: 'Moonlight Ramen',
                      tags: ['Nhật Bản', 'Yêu thích', 'Ramen'],
                      distance: '0.7 km',
                    ),
                    const SizedBox(height: 14),
                    const _RecommendedPlaceItem(
                      index: 3,
                      name: 'B2Q Saigon',
                      tags: ['Bar', 'Lounge', 'Nhạc chill'],
                      distance: '0.9 km',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // === Quick Options ===
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _QuickOptionChip(
                    label: 'Chỉ có non-spicy options',
                    onTap: () => _sendMessage('Chỉ có non-spicy options'),
                  ),
                  _QuickOptionChip(
                    label: 'More romantic & quiet',
                    onTap: () => _sendMessage('More romantic & quiet'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // === Spacer to push the text field to the bottom ===
              const Spacer(),

              // === Chat Input ===
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'What\'s your vibe today?',
                          hintStyle: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _sendMessage(_chatController.text),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4050),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickOptionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QuickOptionChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RecommendedPlaceItem extends StatelessWidget {
  final int index;
  final String name;
  final List<String> tags;
  final String distance;

  const _RecommendedPlaceItem({
    required this.index,
    required this.name,
    required this.tags,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index.',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    distance,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: tags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
