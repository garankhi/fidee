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
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 20),
                  _buildAssistantBubble(
                    'Chào bạn, mình là Fidee. Hãy cho mình biết bạn đang muốn ăn gì, ngân sách, vị trí và phong cách quán. Fidee sẽ gợi ý địa điểm phù hợp cho bạn.',
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildQuickPrompt(),
                  ),
                  const SizedBox(height: 18),
                  _buildRecommendationSummary(),
                  const SizedBox(height: 10),
                  for (final recommendation in _recommendations) ...[
                    _RecommendationCard(recommendation: recommendation),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 6),
                  _buildQuickFilters(),
                  for (final message in _messages) ...[
                    const SizedBox(height: 12),
                    message.isUser
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: _buildUserBubble(message.text),
                          )
                        : _buildAssistantBubble(message.text),
                  ],
                ],
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        ),
        const SizedBox(width: 6),
        ClipOval(
          child: Image.asset(
            'assets/images/Fidee_Red_Round.png',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fidee AI',
              style: TextStyle(
                color: Color(0xFFEF4050),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: Color(0xFF22C55E)),
                SizedBox(width: 6),
                Text(
                  'Đang hoạt động',
                  style: TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickPrompt() {
    return GestureDetector(
      onTap: () => _sendMessage('Gợi ý 3 quán gần tôi'),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4050),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Gợi ý 3 quán gần tôi',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationSummary() {
    return _buildAssistantBubble(
      'Fidee chọn nhanh các quán vừa ngon vừa hợp túi tiền:\n'
      '1. Sân Vườn Cafe - 0,3 km - yên tĩnh, đẹp mắt\n'
      '2. Ramen Ánh Trăng - 0,8 km - ấm cúng, lãng mạn\n'
      '3. Bún Chả Góc Phố - 0,5 km - đậm vị địa phương\n'
      'Một vài bạn của bạn từng ghé các nơi này và đánh giá khá tốt.',
    );
  }

  Widget _buildQuickFilters() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        _QuickOptionChip(
          label: 'Chỉ món không cay',
          onTap: () => _sendMessage('Chỉ món không cay'),
        ),
        _QuickOptionChip(
          label: 'Lãng mạn và yên tĩnh hơn',
          onTap: () => _sendMessage('Lãng mạn và yên tĩnh hơn'),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Hôm nay bạn muốn vibe thế nào?',
                  hintStyle: TextStyle(
                    color: Color(0xFFB6B6B6),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 4),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.image_outlined, color: Color(0xFFC8C8C8)),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.mic_none_rounded, color: Color(0xFFC8C8C8)),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () => _sendMessage(_chatController.text),
              icon: const Icon(Icons.send_rounded, color: Color(0xFFEF4050)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildAssistantBubble(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F0F0),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF4A4A4A),
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget _buildUserBubble(String text) {
  return Container(
    constraints: const BoxConstraints(maxWidth: 280),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFFEF4050),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD8DB),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFEF4050),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final _Recommendation recommendation;

  const _RecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/land_spot.png',
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFFD166), size: 10),
                      const SizedBox(width: 3),
                      Text(
                        recommendation.rating,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2F2F2F),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  recommendation.category,
                  style: const TextStyle(
                    color: Color(0xFF8C8C8C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MiniAction(label: 'Đang mở cửa', filled: false),
                    _MiniAction(label: 'Xem đường đi', filled: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                recommendation.distance,
                style: const TextStyle(
                  color: Color(0xFF2F2F2F),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                recommendation.duration,
                style: const TextStyle(
                  color: Color(0xFF2F2F2F),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String label;
  final bool filled;

  const _MiniAction({required this.label, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFEF4050) : const Color(0xFFFFEFF0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? Colors.white : const Color(0xFFEF4050),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}



