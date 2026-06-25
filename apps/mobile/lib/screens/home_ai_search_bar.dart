import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

class HomeAiSearchBar extends StatefulWidget {
  const HomeAiSearchBar({
    super.key,
    required this.onSubmitted,
    this.onOpenChat,
  });

  final ValueChanged<String> onSubmitted;
  final VoidCallback? onOpenChat;

  @override
  State<HomeAiSearchBar> createState() => _HomeAiSearchBarState();
}

class _HomeAiSearchBarState extends State<HomeAiSearchBar> {
  static const _hintPrompts = [
    'Bạn muốn ăn gì hôm nay nào?',
    'Thời tiết khá là mát mẻ để ăn chè đó',
    'Phân vân không biết lựa thì cứ hỏi Fidey',
  ];
  static const _hintInterval = Duration(seconds: 7);

  final TextEditingController _controller = TextEditingController();
  Timer? _hintTimer;
  int _hintIndex = 0;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    _hintTimer = Timer.periodic(_hintInterval, (_) {
      if (!mounted || _hasText) {
        return;
      }
      setState(() {
        _hintIndex = (_hintIndex + 1) % _hintPrompts.length;
      });
    });
  }

  void _handleTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText == _hasText) {
      return;
    }
    setState(() => _hasText = hasText);
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      return;
    }

    widget.onSubmitted(query);
    _controller.clear();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFFFF3B30)),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (!_hasText)
                  IgnorePointer(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            final blur = (1 - animation.value) * 4;
                            return Opacity(
                              opacity: animation.value,
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: blur,
                                  sigmaY: blur,
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: child,
                        );
                      },
                      child: Text(
                        _hintPrompts[_hintIndex],
                        key: ValueKey(_hintPrompts[_hintIndex]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                TextField(
                  key: const ValueKey('home-ai-search-field'),
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  onSubmitted: _submit,
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('home-ai-chat-button'),
            tooltip: 'Mở Fidey AI',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: widget.onOpenChat,
            icon: Icon(
              Icons.auto_awesome_rounded,
              color: widget.onOpenChat == null
                  ? Colors.grey.shade400
                  : const Color(0xFFFF3B30),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
