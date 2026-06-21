import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/auth/auth_providers.dart';
import '../models/journey_entry.dart';
import '../services/journey_service.dart';
import 'place_details_friends.dart';

enum _JourneyPeriod { all, week, month }

class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({super.key});

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<JourneyEntryType, List<JourneyEntry>> _entries = {
    JourneyEntryType.checkin: <JourneyEntry>[],
    JourneyEntryType.review: <JourneyEntry>[],
  };
  final Map<JourneyEntryType, String?> _nextCursors = {
    JourneyEntryType.checkin: null,
    JourneyEntryType.review: null,
  };
  final Map<JourneyEntryType, bool> _hasMore = {
    JourneyEntryType.checkin: true,
    JourneyEntryType.review: true,
  };
  final Set<JourneyEntryType> _loaded = <JourneyEntryType>{};

  JourneyEntryType _selectedType = JourneyEntryType.checkin;
  _JourneyPeriod _period = _JourneyPeriod.all;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  late final JourneyService _service;

  @override
  void initState() {
    super.initState();
    _service = JourneyService(ref.read(authServiceProvider));
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _load(reset: true));
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) {
      _loadMore();
    }
  }

  Future<void> _load({required bool reset}) async {
    final requestedType = _selectedType;
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final page = await _fetchPage(
        requestedType,
        cursor: reset ? null : _nextCursors[requestedType],
      );
      if (!mounted) return;
      setState(() {
        _entries[requestedType] = reset
            ? page.entries
            : <JourneyEntry>[..._entries[requestedType]!, ...page.entries];
        _nextCursors[requestedType] = page.nextCursor;
        _hasMore[requestedType] = page.hasMore;
        _loaded.add(requestedType);
        if (_selectedType == requestedType) {
          _errorMessage = null;
        }
      });
    } on JourneyException catch (error) {
      if (!mounted) return;
      if (_selectedType == requestedType) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted && _selectedType == requestedType) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<JourneyPage> _fetchPage(JourneyEntryType type, {String? cursor}) {
    return switch (type) {
      JourneyEntryType.checkin => _service.fetchCheckins(cursor: cursor),
      JourneyEntryType.review => _service.fetchReviews(cursor: cursor),
    };
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !(_hasMore[_selectedType] ?? false)) {
      return;
    }
    setState(() => _isLoadingMore = true);
    await _load(reset: false);
  }

  void _selectType(JourneyEntryType type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _errorMessage = null;
      _isLoading = !_loaded.contains(type);
      _isLoadingMore = false;
    });
    if (!_loaded.contains(type)) {
      _load(reset: true);
    }
  }

  List<JourneyEntry> get _visibleEntries {
    final entries = _entries[_selectedType] ?? const <JourneyEntry>[];
    final now = DateTime.now();
    return entries
        .where((entry) {
          final created = entry.createdDate;
          if (created == null || _period == _JourneyPeriod.all) return true;
          final cutoff = switch (_period) {
            _JourneyPeriod.week => now.subtract(const Duration(days: 7)),
            _JourneyPeriod.month => now.subtract(const Duration(days: 30)),
            _JourneyPeriod.all => now,
          };
          return created.isAfter(cutoff);
        })
        .toList(growable: false);
  }

  void _openSpot(JourneyEntry entry) {
    if (entry.placeId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlaceDetailsFriends(placeId: entry.placeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final displayName = <String?>[
      authState?.firstName,
      authState?.lastName,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');
    final userName = displayName.isEmpty ? 'Bạn' : displayName;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFEF4050),
            size: 20,
          ),
        ),
        title: Text(
          'HÀNH TRÌNH',
          style: GoogleFonts.ericaOne(
            color: const Color(0xFFEF4050),
            fontSize: 25,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _JourneyTabs(selected: _selectedType, onSelected: _selectType),
            const SizedBox(height: 12),
            _PeriodFilter(
              period: _period,
              onChanged: (value) => setState(() => _period = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFEF4050),
                onRefresh: () => _load(reset: true),
                child: _buildContent(
                  userName: userName,
                  avatarUrl: authState?.avatarUrl,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({required String userName, String? avatarUrl}) {
    if (_isLoading) {
      return const _JourneySkeletonList();
    }
    if (_errorMessage != null && _entries[_selectedType]!.isEmpty) {
      return _JourneyMessage(
        icon: Icons.cloud_off_rounded,
        message: _errorMessage!,
        actionLabel: 'THỬ LẠI',
        onAction: () => _load(reset: true),
      );
    }

    final visibleEntries = _visibleEntries;
    if (visibleEntries.isEmpty) {
      return _JourneyMessage(
        icon: _selectedType == JourneyEntryType.checkin
            ? Icons.location_on_outlined
            : Icons.rate_review_outlined,
        message: _period == _JourneyPeriod.all
            ? 'Các lần check-in của bạn sẽ hiện ở đây.'
            : 'Các bài đánh giá của bạn sẽ hiện ở đây.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      itemCount: visibleEntries.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == visibleEntries.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFEF4050),
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _JourneyCard(
            entry: visibleEntries[index],
            userName: userName,
            avatarUrl: avatarUrl,
            onOpenSpot: () => _openSpot(visibleEntries[index]),
          ),
        );
      },
    );
  }
}

class _JourneyTabs extends StatelessWidget {
  final JourneyEntryType selected;
  final ValueChanged<JourneyEntryType> onSelected;

  const _JourneyTabs({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 50),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: JourneyEntryType.values
            .map((type) {
              final isSelected = selected == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFFE4E7)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(27),
                    ),
                    child: Text(
                      type == JourneyEntryType.checkin
                          ? 'ĐÃ CHECK-IN'
                          : 'BÀI ĐÁNH GIÁ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFEF4050)
                            : const Color(0xFF222222),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _PeriodFilter extends StatelessWidget {
  final _JourneyPeriod period;
  final ValueChanged<_JourneyPeriod> onChanged;

  const _PeriodFilter({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final labels = <_JourneyPeriod, String>{
      _JourneyPeriod.all: 'Mọi lúc',
      _JourneyPeriod.week: 'Tuần này',
      _JourneyPeriod.month: 'Tháng này',
    };
    return PopupMenuButton<_JourneyPeriod>(
      initialValue: period,
      onSelected: onChanged,
      color: const Color.fromARGB(255, 255, 0, 0),
      itemBuilder: (context) => _JourneyPeriod.values
          .map(
            (value) => PopupMenuItem<_JourneyPeriod>(
              value: value,
              child: Text(labels[value]!),
            ),
          )
          .toList(growable: false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labels[period]!,
              style: const TextStyle(
                color: Color(0xFFEF4050),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFFEF4050),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final JourneyEntry entry;
  final String userName;
  final String? avatarUrl;
  final VoidCallback onOpenSpot;

  const _JourneyCard({
    required this.entry,
    required this.userName,
    required this.avatarUrl,
    required this.onOpenSpot,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = entry.imageUrl;
    final canOpenSpot = entry.placeId.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFFFCDD3),
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Text(
                        userName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFEF4050),
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        userName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1D1D1D),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '- ${entry.relativeTime()}',
                      style: const TextStyle(
                        color: Color(0xFF8B8B8B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (entry.rating != null) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: _RatingStars(rating: entry.rating!),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            entry.placeName.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (entry.category != null && entry.category!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.category!,
              style: const TextStyle(color: Color(0xFF8B8B8B), fontSize: 11),
            ),
          ],
          if (imageUrl != null || (entry.text?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      imageUrl,
                      width: 108,
                      height: 82,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _ImageFallback(),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (entry.text?.isNotEmpty ?? false)
                  Expanded(
                    child: Text(
                      entry.text!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF343434),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entry.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCCD2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFFEF4050),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 13),
          const Divider(height: 1, color: Color(0xFFE7D8DA)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${entry.friendsSavedCount} BẠN ĐÃ LƯU',
                  style: const TextStyle(
                    color: Color(0xFF8B8B8B),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: canOpenSpot ? onOpenSpot : null,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                label: const Text('XEM ĐỊA ĐIỂM'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4050),
                  disabledForegroundColor: const Color(0xFFB9B9B9),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final int rating;

  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(
        5,
        (index) => Icon(
          Icons.star_rounded,
          size: 16,
          color: index < rating
              ? const Color(0xFFEF4050)
              : const Color(0xFFFFB9C1),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 108,
      height: 82,
      child: ColoredBox(
        color: Color(0xFFFFD8DD),
        child: Icon(Icons.restaurant_rounded, color: Color(0xFFEF4050)),
      ),
    );
  }
}

class _JourneyMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _JourneyMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 48, color: const Color(0xFFFFB9C1)),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 14),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ),
        ],
      ],
    );
  }
}

class _JourneySkeletonList extends StatelessWidget {
  const _JourneySkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, _) => Container(
        height: 218,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFECEE),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: Color(0xFFFFCDD3)),
                SizedBox(width: 10),
                _SkeletonBar(width: 100),
              ],
            ),
            const SizedBox(height: 18),
            const _SkeletonBar(width: 150, height: 14),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 108,
                  height: 82,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD8DD),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBar(width: double.infinity),
                      SizedBox(height: 8),
                      _SkeletonBar(width: double.infinity),
                      SizedBox(height: 8),
                      _SkeletonBar(width: 80),
                    ],
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

class _SkeletonBar extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonBar({required this.width, this.height = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD8DD),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
