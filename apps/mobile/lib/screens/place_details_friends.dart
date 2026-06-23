import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/chat_provider.dart';
import '../features/auth/friends_provider.dart';
import '../features/auth/place_provider.dart';
import '../features/auth/review_provider.dart';
import '../services/friend_service.dart';
import '../services/place_candidate_service.dart';
import '../services/upload_service.dart';
import 'camera_screen.dart';

class PlaceDetailsFriends extends ConsumerStatefulWidget {
  final String placeId;

  const PlaceDetailsFriends({super.key, required this.placeId});

  @override
  ConsumerState<PlaceDetailsFriends> createState() =>
      _PlaceDetailsFriendsState();
}

class _PlaceDetailsFriendsState extends ConsumerState<PlaceDetailsFriends> {
  static const String _serverBaseUrl = 'https://api.fidee.site';
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _reviewsKey = GlobalKey();
  bool _isUploadingCover = false;

  String _getFullImageUrl(dynamic mediaId) {
    if (mediaId == null || mediaId.toString().isEmpty) {
      return '';
    }

    final value = mediaId.toString();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    return '$_serverBaseUrl/media/$value';
  }

  String _formatDisplayTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'Chưa rõ';
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return timeStr;
  }

  void showSuccessDialog(int rating, String content) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text(
                'Thành công!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Đóng',
                style: TextStyle(color: Color(0xFFEF484F), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref
          .read(placeControllerProvider.notifier)
          .fetchPlaceDetail(widget.placeId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _currentUserDisplayName(AuthUiState? authState) {
    final preferredUsername = authState?.preferredUsername?.trim();
    if (preferredUsername != null && preferredUsername.isNotEmpty) {
      return preferredUsername;
    }

    final nameParts = [
      authState?.firstName?.trim(),
      authState?.lastName?.trim(),
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

    return nameParts.isEmpty ? 'Bạn' : nameParts;
  }

  void _scrollToReviews() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _reviewsKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  String _buildShareUrl(Place place) {
    final placeId = place.id?.trim().isNotEmpty == true
        ? place.id!.trim()
        : widget.placeId;
    return 'https://fidee.site/places/$placeId';
  }

  String _buildShareText(Place place) {
    final name = place.name?.trim().isNotEmpty == true
        ? place.name!.trim()
        : 'địa điểm này';
    final address = place.address?.trim();
    final buffer = StringBuffer('Xem $name trên Fidee');
    if (address != null && address.isNotEmpty) {
      buffer.write('\n$address');
    }
    buffer.write('\n${_buildShareUrl(place)}');
    return buffer.toString();
  }

  String _buildInAppShareText(Place place) {
    final name = place.name?.trim().isNotEmpty == true
        ? place.name!.trim()
        : 'địa điểm này';
    final address = place.address?.trim();
    final placeId = place.id?.trim().isNotEmpty == true
        ? place.id!.trim()
        : widget.placeId;
    final buffer = StringBuffer('Xem $name trên Fidee');
    if (address != null && address.isNotEmpty) {
      buffer.write('\n$address');
    }
    buffer.write('\n\u2063fidee_place:$placeId');
    return buffer.toString();
  }

  Future<void> _copyShareText(Place place) async {
    await Clipboard.setData(ClipboardData(text: _buildShareText(place)));
    if (!mounted) return;
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép liên kết địa điểm')),
    );
  }

  void _showShareSheet(Place place) {
    final name = place.name?.trim().isNotEmpty == true
        ? place.name!.trim()
        : 'Địa điểm Fidee';
    final address = place.address?.trim();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Chia sẻ địa điểm',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (address != null && address.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          address,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showFriendShareSheet(place);
                    },
                    icon: const Icon(Icons.people_alt_rounded, size: 18),
                    label: const Text('Gửi cho bạn bè trong Fidee'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF484F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _copyShareText(place),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Sao chép liên kết'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF484F),
                      side: const BorderSide(color: Color(0xFFEF484F)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _sendPlaceToFriend({
    required Place place,
    required FriendProfile friend,
  }) async {
    final conversationId = await ref
        .read(chatInboxControllerProvider.notifier)
        .openDirectConversation(friend.id);
    if (conversationId == null || conversationId.isEmpty) return false;

    final chatService = ref.read(userChatServiceProvider);
    final sent = await chatService.sendMessage(
      conversationId: conversationId,
      clientMessageId: chatService.createClientMessageId(),
      body: _buildInAppShareText(place),
    );
    if (sent == null) return false;

    await ref.read(chatInboxControllerProvider.notifier).load(silent: true);
    return true;
  }

  void _showFriendShareSheet(Place place) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        final selectedFriendIds = <String>{};
        var isSending = false;
        var searchQuery = '';

        return Consumer(
          builder: (context, ref, _) {
            final friendsState = ref.watch(friendsControllerProvider);
            final friends = friendsState.friends
                .where((friend) => friend.id != friendsState.currentUserId)
                .toList(growable: false);

            return StatefulBuilder(
              builder: (context, setSheetState) {
                final normalizedQuery = searchQuery.trim().toLowerCase();
                final filteredFriends = normalizedQuery.isEmpty
                    ? friends
                    : friends.where((friend) {
                        return friend.name.toLowerCase().contains(
                              normalizedQuery,
                            ) ||
                            friend.handle.toLowerCase().contains(
                              normalizedQuery,
                            );
                      }).toList(growable: false);

                Future<void> sendSelected() async {
                  if (selectedFriendIds.isEmpty || isSending) return;
                  final sheetNavigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(this.context);
                  setSheetState(() {
                    isSending = true;
                  });

                  var sentCount = 0;
                  final selectedFriends = friends
                      .where(
                        (friend) => selectedFriendIds.contains(friend.id),
                      )
                      .toList(growable: false);

                  for (final friend in selectedFriends) {
                    final success = await _sendPlaceToFriend(
                      place: place,
                      friend: friend,
                    );
                    if (success) sentCount++;
                  }

                  if (!mounted) return;
                  sheetNavigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        sentCount == selectedFriends.length
                            ? 'Đã gửi địa điểm cho $sentCount bạn'
                            : 'Đã gửi $sentCount/${selectedFriends.length} bạn',
                      ),
                    ),
                  );
                }

                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 14,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Gửi cho bạn bè',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          enabled: !isSending,
                          onChanged: (value) {
                            setSheetState(() {
                              searchQuery = value;
                            });
                          },
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tìm bạn bè...',
                            hintStyle: const TextStyle(
                              color: Colors.black38,
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFFEF484F),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7F7F7),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFFE8E8E8),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFFE8E8E8),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFFEF484F),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (friendsState.isInitialLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFEF484F),
                              ),
                            ),
                          )
                        else if (friends.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: Text(
                                'Bạn chưa có bạn bè để chia sẻ.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        else if (filteredFriends.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: Text(
                                'Không tìm thấy bạn bè phù hợp.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.45,
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredFriends.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final friend = filteredFriends[index];
                                final isSelected = selectedFriendIds.contains(
                                  friend.id,
                                );

                                return CheckboxListTile(
                                  value: isSelected,
                                  activeColor: const Color(0xFFEF484F),
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: isSending
                                      ? null
                                      : (value) {
                                          setSheetState(() {
                                            if (value == true) {
                                              selectedFriendIds.add(friend.id);
                                            } else {
                                              selectedFriendIds.remove(
                                                friend.id,
                                              );
                                            }
                                          });
                                        },
                                  title: Text(
                                    friend.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: friend.handle.isEmpty
                                      ? null
                                      : Text(
                                          '@${friend.handle}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  secondary: CircleAvatar(
                                    backgroundColor: const Color(0xFFFFE1E5),
                                    backgroundImage:
                                        friend.avatarUrl != null &&
                                            friend.avatarUrl!.isNotEmpty
                                        ? NetworkImage(friend.avatarUrl!)
                                        : null,
                                    child:
                                        friend.avatarUrl != null &&
                                            friend.avatarUrl!.isNotEmpty
                                        ? null
                                        : Text(
                                            friend.initials,
                                            style: const TextStyle(
                                              color: Color(0xFFEF484F),
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: selectedFriendIds.isEmpty || isSending
                                ? null
                                : sendSelected,
                            icon: isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              isSending
                                  ? 'Đang gửi...'
                                  : 'Gửi (${selectedFriendIds.length})',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF484F),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(
                                0xFFFFC2C6,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndUploadCover(Place place) async {
    if (!place.isCandidate || place.id == null) return;
    
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _isUploadingCover = true;
    });

    try {
      final uploadService = UploadService(authService: ref.read(authServiceProvider));
      final file = File(image.path);
      
      final mediaId = await uploadService.upload(
        imagePath: file.path,
        longitude: place.lng ?? 0,
        latitude: place.lat ?? 0,
        source: 'EXIF_GALLERY',
        contentTypeOverride: 'image/jpeg',
      );
      
      final placeCandidateService = PlaceCandidateService(ref.read(authServiceProvider));
      await placeCandidateService.updateCandidate(
        candidateId: place.id!,
        mediaId: mediaId,
      );
      
      await ref.read(placeControllerProvider.notifier).fetchPlaceDetail(place.id!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ảnh bìa thành công!')),
        );
      }
    } catch (e, st) {
      debugPrint('Upload error: $e');
      debugPrint('Stacktrace: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingCover = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = ref.watch(placeControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  toolbarHeight: 100,
                  pinned: true,
                  backgroundColor: Colors.white,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 10),
                    child: Center(
                      child: CircleAvatar(
                        backgroundColor: const Color(0x19EF484F),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 16,
                            color: Color(0xFFEF484F),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                  title: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      (place.name ?? 'CHI TIẾT ĐỊA ĐIỂM').toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFC52128),
                        fontSize: 22,
                        fontFamily: 'Anton',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  centerTitle: true,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                        top: 10,
                      ),
                      child: Center(
                        child: CircleAvatar(
                          backgroundColor: const Color(0x19EF484F),
                          child: IconButton(
                            icon: const Icon(
                              Icons.share,
                              size: 18,
                              color: Color(0xFFEF484F),
                            ),
                            onPressed: () => _showShareSheet(place),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 10,
                    bottom: 120,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildBannerCard(place),
                      const SizedBox(height: 20),
                      _buildInfoSpot(place),
                      const SizedBox(height: 20),
                      _buildCategoryTags(place),
                      const SizedBox(height: 20),
                      _buildAmenities(place),
                      const SizedBox(height: 25),
                      _buildLargeButton(Icons.near_me, 'Chỉ đường'),
                      const SizedBox(height: 25),
                      _buildFriendCheckins(place),
                      const SizedBox(height: 25),
                      KeyedSubtree(
                        key: _reviewsKey,
                        child: _buildFriendReviews(place),
                      ),
                      const SizedBox(height: 25),
                      _buildPhotoGallery(place),
                    ]),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const CameraScreen(),
                              ),
                            );
                          },
                          child: _buildBottomButton(Icons.camera_alt, 'Check-in'),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showRatingBottomSheet(),
                          child: _buildBottomButton(Icons.edit, 'Đánh giá'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPONENT WIDGETS ---

  Widget _buildBannerCard(Place place) {
    final bannerUrl = _getFullImageUrl(place.coverMediaId);

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF303E42),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (bannerUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  bannerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 40,
                        color: Colors.white30,
                      ),
                    );
                  },
                ),
              ),

            if (bannerUrl.isEmpty)
              Positioned.fill(
                child: (place.isCreator && place.isCandidate) ? GestureDetector(
                  onTap: _isUploadingCover ? null : () => _pickAndUploadCover(place),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isUploadingCover)
                          const CircularProgressIndicator(color: Color(0xFFEF484F))
                        else ...[
                          const Icon(Icons.add_a_photo, size: 40, color: Colors.white54),
                          const SizedBox(height: 8),
                          const Text(
                            'Thêm ảnh bìa',
                            style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                ) : const Center(
                  child: Icon(Icons.image, size: 40, color: Colors.white30),
                ),
              ),

            Positioned(
              top: 15,
              left: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      place.avgRating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            place.name ?? 'Chưa cập nhật tên',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '📍 ${place.address ?? "Chưa cập nhật địa chỉ"}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF229D00),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Đang mở cửa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đóng ${_formatDisplayTime(place.closeTime)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSpot(Place place) {
    String formatCurrency(int? amount) {
      if (amount == null) return '0';
      if (amount >= 1000) return '${amount ~/ 1000}k';
      return amount.toString();
    }

    final String priceRange = (place.priceMin != null && place.priceMax != null)
        ? '${formatCurrency(place.priceMin)} - ${formatCurrency(place.priceMax)} VND'
        : 'Chưa cập nhật tầm giá';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7C6C7), Color(0xFFF2F1F0)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THÔNG TIN QUÁN',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            'Mô tả:',
            ' ${place.description ?? "Chưa có mô tả chi tiết cho địa điểm này."}',
          ),
          _buildInfoRow(
            'Khung giờ hoạt động:',
            ' ${_formatDisplayTime(place.openTime)} - ${_formatDisplayTime(place.closeTime)}',
          ),
          _buildInfoRow('Tầm giá:', ' $priceRange'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTags(Place place) {
    if (place.vibes.isNotEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: place.vibes
            .map((vibe) => _buildTag('✨ ${vibe.toUpperCase()}'))
            .toList(),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTag(
          place.category != null
              ? '✨ ${place.category!.toUpperCase()}'
              : '✨ CAFE',
        ),
        _buildTag('🛡️ Đã xác minh'),
        _buildTag('💵 Tầm Giá Tốt'),
      ],
    );
  }

  Widget _buildAmenities(Place place) {
    if (place.services.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tiện nghi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: place.services
              .map((service) => _buildTag(service.toString()))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF46090C),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildLargeButton(IconData icon, String text) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFEF484F),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCheckins(Place place) {
    final checkins = place.friendCheckins;
    final visibleCheckinCount = checkins.length;

    return Column(
      children: [
        _buildSectionHeader(
          'Check-in của bạn bè ($visibleCheckinCount)',
          onViewAll: checkins.isEmpty
              ? null
              : () => _showAllCheckinsSheet(checkins, place),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 165,
          child: checkins.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có check-in từ bạn bè',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: checkins.length,
            itemBuilder: (context, index) {
              final item = checkins[index] as Map<String, dynamic>;

              final String checkinPhoto = _getFullImageUrl(
                item['mediaId'] ?? item['url'],
              );

              return GestureDetector(
                onTap: () => _openCheckinDetail(item, place),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 12, bottom: 5, top: 5),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFC5C5C5).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['userName']?.toString() ?? item['name']?.toString() ?? 'Bạn bè',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: checkinPhoto.isNotEmpty
                              ? Image.network(
                            checkinPhoto,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image, color: Colors.white),
                            ),
                          )
                              : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          item['createdAt']?.toString().split('T').first ?? '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendReviews(Place place) {
    final reviews = place.friendReviews;
    final allReviews = <dynamic>[...place.friendReviews, ...place.otherReviews];

    if (reviews.isEmpty) {
      return Column(
        children: [
          _buildSectionHeader(
            'Bạn bè nói gì về quán này?',
            onViewAll: allReviews.isEmpty
                ? null
                : () => _showAllReviewsSheet(allReviews),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Chưa có đánh giá từ bạn bè',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildSectionHeader(
          'Bạn bè nói gì về quán này? (${reviews.length})',
          onViewAll: allReviews.isEmpty
              ? null
              : () => _showAllReviewsSheet(allReviews),
        ),
        const SizedBox(height: 12),
        ...reviews.map((review) {
          final item = review as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildReviewCard(item),
          );
        }),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final bool isFeatured = review['isFeatured'] == true;
    final mediaIds = _reviewMediaIds(review);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7C6C7), Color(0x91EAE9E8)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(
                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['userName']?.toString() ?? 'Người dùng',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        (review['rating'] ?? 0) as int,
                            (index) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFeatured ? const Color(0xFFEF484F) : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFeatured ? 'NỔI BẬT' : 'ĐÁNH GIÁ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review['content']?.toString() ?? '',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (mediaIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mediaIds.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final imageUrl = _getFullImageUrl(mediaIds[index]);
                  return GestureDetector(
                    onTap: () => _showReviewPhotoViewer(mediaIds, index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 78,
                        height: 78,
                        color: Colors.white.withValues(alpha: 0.55),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.black38,
                                ),
                              )
                            : const Icon(
                                Icons.image_outlined,
                                color: Colors.black38,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _reviewMediaIds(Map<String, dynamic> review) {
    final raw = review['mediaIds'] ?? review['media_ids'];
    if (raw is! Iterable) return const <String>[];

    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  void _showReviewPhotoViewer(List<String> mediaIds, int initialIndex) {
    final controller = PageController(initialPage: initialIndex);
    var currentIndex = initialIndex;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.black,
              child: SafeArea(
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: controller,
                      itemCount: mediaIds.length,
                      onPageChanged: (index) {
                        setDialogState(() => currentIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final imageUrl = _getFullImageUrl(mediaIds[index]);
                        return InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Center(
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white54,
                                      size: 48,
                                    ),
                                  )
                                : const Icon(
                                    Icons.image_outlined,
                                    color: Colors.white54,
                                    size: 48,
                                  ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    if (mediaIds.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 18,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${currentIndex + 1}/${mediaIds.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhotoGallery(Place place) {
    final photos = place.photos;

    return Column(
      children: [
        _buildSectionHeader(
          'Ảnh (${photos.length})',
          onViewAll: photos.isEmpty ? null : () => _showAllPhotosSheet(photos),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE6E6E6),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: Colors.grey,
                size: 32,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 100,
                child: photos.isEmpty
                    ? const Center(child: Text('Chưa có ảnh', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photoItem = photos[index] as Map<String, dynamic>;
                    final String galleryPhotoUrl = _getFullImageUrl(
                      photoItem['mediaId'] ?? photoItem['url'],
                    );
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: const Color(0xFF303E42),
                        image: galleryPhotoUrl.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(galleryPhotoUrl),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          if (galleryPhotoUrl.isEmpty)
                            const Center(child: Icon(Icons.image, color: Colors.white24)),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(15),
                                  bottomRight: Radius.circular(15),
                                ),
                              ),
                              child: Text(
                                photoItem['userName']?.toString() ?? 'Ẩn danh',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text(
              'Xem tất cả',
              style: TextStyle(
                color: Color(0xFFEF484F),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  void _showAllReviewsSheet(List<dynamic> reviews) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        'Tất cả đánh giá (${reviews.length})',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index] as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildReviewCard(review),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAllCheckinsSheet(List<dynamic> checkins, Place place) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        'Tất cả check-in (${checkins.length})',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: checkins.length,
                    itemBuilder: (context, index) {
                      final item = checkins[index] as Map<String, dynamic>;
                      final imageUrl = _getFullImageUrl(
                        item['mediaId'] ?? item['url'],
                      );
                      return _buildCheckinSheetCard(item, imageUrl, place);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCheckinSheetCard(
    Map<String, dynamic> item,
    String imageUrl,
    Place place,
  ) {
    return GestureDetector(
      onTap: () => _openCheckinDetail(item, place),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['userName']?.toString() ?? item['name']?.toString() ?? 'Bạn bè',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item['createdAt']?.toString().split('T').first ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _openCheckinDetail(Map<String, dynamic> checkin, Place place) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _CheckinDetailScreen(
          checkin: checkin,
          place: place,
          imageUrl: _getFullImageUrl(checkin['mediaId'] ?? checkin['url']),
        ),
      ),
    );
  }

  void _showAllPhotosSheet(List<dynamic> photos) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        'Tất cả ảnh (${photos.length})',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final item = photos[index] as Map<String, dynamic>;
                      final imageUrl = _getFullImageUrl(
                        item['mediaId'] ?? item['url'],
                      );
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.white,
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBottomButton(IconData icon, String text) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFEF484F),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return NewRatingBottomSheet(
          placeId: widget.placeId,
          userName: _currentUserDisplayName(
            ref.read(authControllerProvider).valueOrNull,
          ),
          onSuccess: (review) {
            ref
                .read(placeControllerProvider.notifier)
                .prependFriendReview(review);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã gửi đánh giá')),
            );
            _scrollToReviews();
          },
        );
      },
    );
  }
}

class _CheckinDetailScreen extends StatelessWidget {
  final Map<String, dynamic> checkin;
  final Place place;
  final String imageUrl;

  const _CheckinDetailScreen({
    required this.checkin,
    required this.place,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final userName =
        checkin['userName']?.toString() ?? checkin['name']?.toString() ?? 'Bạn bè';
    final userAvatar = checkin['userAvatar']?.toString();
    final caption = checkin['caption']?.toString().trim() ?? '';
    final createdAt = checkin['createdAt']?.toString().split('T').first ?? '';
    final rating = int.tryParse(checkin['rating']?.toString() ?? '') ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFEF484F)),
        ),
        title: const Text(
          'Chi tiết check-in',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 1,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFFE1E5),
                backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                    ? NetworkImage(userAvatar)
                    : null,
                child: userAvatar != null && userAvatar.isNotEmpty
                    ? null
                    : Text(
                        userName.trim().isEmpty
                            ? 'U'
                            : userName.trim().substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFEF484F),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      place.name ?? 'Địa điểm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (rating > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
            ),
          ],
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              caption,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              createdAt,
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NewRatingBottomSheet extends ConsumerStatefulWidget {
  final String placeId;
  final String userName;
  final void Function(Map<String, dynamic> review) onSuccess;

  const NewRatingBottomSheet({
    super.key,
    required this.placeId,
    required this.userName,
    required this.onSuccess,
  });

  @override
  ConsumerState<NewRatingBottomSheet> createState() => _NewRatingBottomSheetState();
}

class _NewRatingBottomSheetState extends ConsumerState<NewRatingBottomSheet> {
  int _rating = 0;
  bool _isPrivate = false;
  final TextEditingController _commentController = TextEditingController();

  final List<String> _tags = ['Vibe chill', 'Phục vụ nhanh', 'Hợp khẩu vị'];
  final Set<String> _selectedTags = {};

  String? _selectedImagePath;
  bool _isUploadingImageLocal = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (pickedFile == null) return;
    setState(() {
      _selectedImagePath = pickedFile.path;
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewControllerProvider);
    final bool isLoading = reviewState.isLoading;
    final bool isBusy = isLoading || _isUploadingImageLocal;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- HEADER BAR ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                ),
                const Text(
                  'GỬI ĐÁNH GIÁ',
                  style: TextStyle(
                    color: Color(0xFFB92830),
                    fontSize: 28,
                    fontFamily: 'Anton',
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.36,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 22),

            // --- UPLOAD ẢNH CHECK-IN ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Thả ảnh check-in của bạn ',
                      style: TextStyle(
                        color: Color(0xFF1E1E1E),
                        fontSize: 16,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '*',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: isBusy ? null : _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E6E6),
                        borderRadius: BorderRadius.circular(20),
                        image: _selectedImagePath != null
                            ? DecorationImage(
                                image: FileImage(File(_selectedImagePath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImagePath == null
                          ? const Icon(
                              Icons.add_a_photo_outlined,
                              color: Color(0xFFA6A6A6),
                              size: 32,
                            )
                          : null,
                    ),
                  ),
                  if (_selectedImagePath != null && !isBusy)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImagePath = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // --- CHỌN SỐ SAO (RATING) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: isBusy ? null : () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                  icon: Icon(
                    index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: index < _rating ? Colors.amber : const Color(0xFFD9D9D9),
                    size: 40,
                  ),
                );
              }),
            ),
            const SizedBox(height: 22),

            // --- DANH SÁCH TAGS ---
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _tags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return InkWell(
                  onTap: isBusy ? null : () {
                    setState(() {
                      if (isSelected) {
                        _selectedTags.remove(tag);
                      } else {
                        _selectedTags.add(tag);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEF484F) : const Color(0x19FF9296),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSelected ? '✓ ' : '+ ',
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFFEF484F),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          tag,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFFEF484F),
                            fontSize: 14,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            // --- Ô NHẬP CẢM NHẬN ---
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 500,
              enabled: !isBusy,

              style: const TextStyle(
                color: Color(0xFF1E1E1E),
                fontSize: 16,
                fontFamily: 'SF Pro',
              ),

              decoration: InputDecoration(
                hintText: 'Chia sẻ cảm nhận của bạn...',
                hintStyle: const TextStyle(color: Color(0xFFA6A6A6), fontSize: 15),
                fillColor: const Color(0x7FEFEFEF),
                filled: true,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFEF484F)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- ẨN DANH / RIÊNG TƯ SWITCH ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hiển thị đánh giá ẩn danh',
                  style: TextStyle(
                    color: Color(0xFF1E1E1E),
                    fontSize: 16,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Switch.adaptive(
                  value: _isPrivate,
                  activeThumbColor: const Color(0xFFEF484F),
                  onChanged: isBusy ? null : (value) {
                    setState(() {
                      _isPrivate = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),

            // --- NÚT XÁC NHẬN ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_rating == 0 || _selectedImagePath == null || isBusy)
                    ? null
                    : () async {
                  setState(() {
                    _isUploadingImageLocal = true;
                  });

                  String? uploadedMediaId;
                  if (_selectedImagePath != null) {
                    try {
                      final place = ref.read(placeControllerProvider);
                      final lat = (place.lat != null && place.lat != 0) ? place.lat! : 10.762892;
                      final lng = (place.lng != null && place.lng != 0) ? place.lng! : 106.682586;

                      final authService = ref.read(authServiceProvider);
                      final uploadService = UploadService(authService: authService);

                      uploadedMediaId = await uploadService.upload(
                        imagePath: _selectedImagePath!,
                        latitude: lat,
                        longitude: lng,
                        source: 'IN_APP_CAMERA',
                      );
                    } catch (e) {
                      if (!mounted) return;
                      setState(() {
                        _isUploadingImageLocal = false;
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi tải ảnh lên: $e')),
                        );
                      }
                      return;
                    }
                  }

                  String finalContent = _commentController.text.trim();
                  if (_selectedTags.isNotEmpty) {
                    final String tagsString = _selectedTags.map((e) => '#$e').join(' ');
                    finalContent = finalContent.isEmpty
                        ? tagsString
                        : '$finalContent\n$tagsString';
                  }

                  final String visibilityParam = _isPrivate ? 'PRIVATE' : 'FRIENDS';

                  final Map<String, dynamic> apiPayload = {
                    'placeId': widget.placeId,
                    'candidateId': null,
                    'rating': _rating,
                    'content': finalContent.isEmpty ? null : finalContent,
                    'visibility': visibilityParam,
                    if (uploadedMediaId != null) 'mediaIds': [uploadedMediaId],
                  };

                  final isSuccess = await ref
                      .read(reviewControllerProvider.notifier)
                      .submitReview(apiPayload);

                  if (isSuccess && context.mounted) {
                    final submittedReview = <String, dynamic>{
                      'id': uploadedMediaId ?? DateTime.now().toIso8601String(),
                      'userName': widget.userName,
                      'rating': _rating,
                      'content': finalContent,
                      'createdAt': DateTime.now().toIso8601String(),
                      'mediaIds': uploadedMediaId == null
                          ? const <String>[]
                          : <String>[uploadedMediaId],
                    };
                    Navigator.pop(context);
                    widget.onSuccess(submittedReview);

                    ref.read(reviewControllerProvider.notifier).resetState();
                  } else {
                    if (!mounted) return;
                    setState(() {
                      _isUploadingImageLocal = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF484F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: isBusy
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text(
                  'Xác nhận',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
