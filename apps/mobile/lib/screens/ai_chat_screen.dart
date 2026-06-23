import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_providers.dart';
import '../services/ai_search_service.dart';
import 'place_details_friends.dart';

typedef AiSearchRunner =
    Future<AiSearchResult> Function(
      String prompt,
      List<AiChatHistoryMessage> history,
      List<AiContextPlace> contextPlaces,
    );

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, this.initialMessage, this.search});

  final String? initialMessage;
  final AiSearchRunner? search;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.places = const <AiPlaceResult>[],
  });

  final String text;
  final bool isUser;
  final List<AiPlaceResult> places;
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _chatController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  List<AiContextPlace> _contextPlaces = const <AiContextPlace>[];
  bool _isWaitingForAnswer = false;

  @override
  void initState() {
    super.initState();

    final initialMessage = widget.initialMessage?.trim();
    if (initialMessage == null || initialMessage.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sendMessage(initialMessage);
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty || _isWaitingForAnswer) return;

    final history = _messages
        .map(
          (message) => AiChatHistoryMessage(
            role: message.isUser ? 'user' : 'model',
            text: message.text,
          ),
        )
        .toList(growable: false);
    final contextPlaces = _contextPlaces;

    setState(() {
      _messages.add(_ChatMessage(text: trimmedMessage, isUser: true));
      _isWaitingForAnswer = true;
    });
    _chatController.clear();

    try {
      final search = widget.search ?? _searchWithApi;
      final result = await search(trimmedMessage, history, contextPlaces);
      if (!mounted) return;

      final places = result.results.take(5).toList(growable: false);
      setState(() {
        if (places.isNotEmpty) {
          _contextPlaces = places
              .map((place) => place.toContextPlace())
              .toList(growable: false);
        }
        _messages.add(
          _ChatMessage(
            text: _cleanAssistantAnswer(
              result.answer,
              hasPlaces: places.isNotEmpty,
            ),
            places: places,
            isUser: false,
          ),
        );
        _isWaitingForAnswer = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: error is AiSearchException
                ? error.message
                : 'Fidee AI đang hơi bận. Bạn thử lại sau một chút nhé.',
            isUser: false,
          ),
        );
        _isWaitingForAnswer = false;
      });
    }
  }

  String _cleanAssistantAnswer(String answer, {required bool hasPlaces}) {
    final trimmed = answer.trim();
    if (trimmed.isEmpty) {
      return hasPlaces
          ? 'Mình tìm được vài địa điểm hợp vibe của bạn:'
          : 'Mình chưa tìm được gợi ý phù hợp. Bạn thử mô tả rõ hơn về món, khu vực hoặc ngân sách nhé.';
    }
    if (!hasPlaces) return trimmed;

    final lines = trimmed
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) {
          final normalized = line.replaceFirst(RegExp(r'^[-*•]\s*'), '');
          return !RegExp(r'^\d+[\.\)]\s+').hasMatch(normalized) &&
              !normalized.startsWith('**') &&
              !normalized.startsWith('Tên:') &&
              !normalized.startsWith('Địa chỉ:');
        })
        .toList(growable: false);

    if (lines.isEmpty) return 'Mình tìm được vài địa điểm hợp vibe của bạn:';

    final summary = lines.take(2).join(' ');
    return summary.length > 220 ? '${summary.substring(0, 217)}...' : summary;
  }

  Future<AiSearchResult> _searchWithApi(
    String prompt,
    List<AiChatHistoryMessage> history,
    List<AiContextPlace> contextPlaces,
  ) {
    final authService = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(authServiceProvider);
    return AiSearchService(authService).search(
      prompt: prompt,
      history: history,
      contextPlaces: contextPlaces,
    );
  }

  void _openPlace(AiPlaceResult place) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlaceDetailsFriends(placeId: place.id),
      ),
    );
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _AiHeader(),
                      const SizedBox(height: 24),
                      const _IntroBubble(),
                      const SizedBox(height: 24),
                      _PrimaryPromptButton(
                        enabled: !_isWaitingForAnswer,
                        onTap: () => _sendMessage('Gợi ý 3 quán gần tôi'),
                      ),
                      const SizedBox(height: 24),
                      const _SampleRecommendationCard(),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _QuickOptionChip(
                            label: 'Chỉ món không cay',
                            onTap: _isWaitingForAnswer
                                ? null
                                : () => _sendMessage('Chỉ món không cay'),
                          ),
                          _QuickOptionChip(
                            label: 'Lãng mạn và yên tĩnh hơn',
                            onTap: _isWaitingForAnswer
                                ? null
                                : () =>
                                      _sendMessage('Lãng mạn và yên tĩnh hơn'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      for (final message in _messages) ...[
                        _ChatMessageView(
                          message: message,
                          onPlaceTap: _openPlace,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_isWaitingForAnswer) const _ThinkingBubble(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ChatInputBar(
                controller: _chatController,
                enabled: !_isWaitingForAnswer,
                onSubmit: _sendMessage,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiHeader extends StatelessWidget {
  const _AiHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFEF4050),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'F',
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
              'Fidee AI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 2),
            Row(
              children: [
                Text('⚡', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Text(
                  'Đang hoạt động',
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
    );
  }
}

class _IntroBubble extends StatelessWidget {
  const _IntroBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Chào bạn, mình là Fidee. Cứ nói món bạn đang thèm, ngân sách, khu vực hoặc vibe hôm nay, mình sẽ gợi ý vài chỗ hợp gu ngay.',
        style: TextStyle(fontSize: 14, color: Colors.black, height: 1.5),
      ),
    );
  }
}

class _PrimaryPromptButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _PrimaryPromptButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFEF4050) : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Center(
          child: Text(
            'Gợi ý 3 quán gần tôi',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _SampleRecommendationCard extends StatelessWidget {
  const _SampleRecommendationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Fidee đang đọc vibe của bạn',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 16),
          _RecommendedPlaceItem(
            index: 1,
            name: 'The Garden',
            tags: ['Nhà hàng', 'Cafe', 'Thoải mái'],
            distance: '0.5 km',
          ),
          SizedBox(height: 14),
          _RecommendedPlaceItem(
            index: 2,
            name: 'Moonlight Ramen',
            tags: ['Nhật Bản', 'Yêu thích', 'Ramen'],
            distance: '0.7 km',
          ),
          SizedBox(height: 14),
          _RecommendedPlaceItem(
            index: 3,
            name: 'B2Q Saigon',
            tags: ['Bar', 'Lounge', 'Nhạc chill'],
            distance: '0.9 km',
          ),
        ],
      ),
    );
  }
}

class _ChatMessageView extends StatelessWidget {
  final _ChatMessage message;
  final ValueChanged<AiPlaceResult> onPlaceTap;

  const _ChatMessageView({
    required this.message,
    required this.onPlaceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFFEF4050)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
            if (message.places.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final place in message.places)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AiPlaceCard(
                    place: place,
                    onTap: () => onPlaceTap(place),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiPlaceCard extends StatelessWidget {
  final AiPlaceResult place;
  final VoidCallback onTap;

  const _AiPlaceCard({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E8E8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0E1B16),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFEF4050),
                    size: 20,
                  ),
                ],
              ),
              if (place.address?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  place.address!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (place.matchLabel.isNotEmpty)
                    _PlaceTag(label: place.matchLabel, isHighlight: true),
                  if (place.priceLabel.isNotEmpty)
                    _PlaceTag(label: place.priceLabel),
                  for (final tag in place.tags.take(3)) _PlaceTag(label: tag),
                ],
              ),
              if (place.description?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(
                  place.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF303030),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceTag extends StatelessWidget {
  final String label;
  final bool isHighlight;

  const _PlaceTag({required this.label, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFFFE6E8) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isHighlight ? const Color(0xFFEF4050) : Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Fidee đang tìm gợi ý phù hợp...',
          style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.35),
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSubmit;

  const _ChatInputBar({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              enableSuggestions: true,
              autocorrect: true,
              cursorColor: const Color(0xFFEF4050),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                height: 1.3,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Hôm nay bạn muốn vibe thế nào?',
                hintStyle: TextStyle(color: Colors.black54, fontSize: 14),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              enabled: enabled,
              onSubmitted: onSubmit,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: enabled ? () => onSubmit(controller.text) : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: enabled ? const Color(0xFFEF4050) : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedPlaceItem extends StatelessWidget {
  const _RecommendedPlaceItem({
    required this.index,
    required this.name,
    required this.tags,
    required this.distance,
  });

  final int index;
  final String name;
  final List<String> tags;
  final String distance;

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
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                children: tags.map((tag) => _PlaceTag(label: tag)).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickOptionChip extends StatelessWidget {
  const _QuickOptionChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

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
