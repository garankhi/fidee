import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/friends_provider.dart';
import '../features/friends/widgets/friend_request_widgets.dart';
import '../services/auth_service.dart';
import 'edit_profile_sheet.dart';
import 'friends_detail_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;

  String _getInitials(String firstName, String lastName) {
    final first = firstName.trim().isNotEmpty
        ? firstName.trim().substring(0, 1)
        : '';
    final last = lastName.trim().isNotEmpty
        ? lastName.trim().substring(0, 1)
        : '';
    if (first.isEmpty && last.isEmpty) return 'U';
    return '$first$last'.toUpperCase();
  }

  Future<void> _pickAndUploadImage(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final token = await authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final file = File(pickedFile.path);
      final length = await file.length();
      final extension = pickedFile.path.split('.').last.toLowerCase();
      final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

      // 1. Get S3 Presigned Post URL from Backend
      final presignedResponse = await http.post(
        Uri.parse('${Config.apiBaseUrl}/media/avatar'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: jsonEncode({'contentType': contentType, 'contentLength': length}),
      );

      if (presignedResponse.statusCode != 200) {
        throw Exception('Không lấy được URL upload từ S3');
      }

      final presignedData = jsonDecode(presignedResponse.body);
      final mediaId = presignedData['mediaId'] as String;
      final upload = presignedData['upload'] as Map<String, dynamic>;
      final uploadUrl = upload['url'] as String;
      final fields = Map<String, String>.from(upload['fields'] as Map);

      // 2. Upload file directly to S3 via Multipart request
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      for (final entry in fields.entries) {
        request.fields[entry.key] = entry.value;
      }
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final uploadResponse = await request.send();

      if (uploadResponse.statusCode != 204) {
        throw Exception('Upload ảnh lên S3 thất bại');
      }

      // 3. Construct public CloudFront CDN or S3 file URL
      final cdnUrl = presignedData['cdnUrl'] as String?;
      final String fileUrl;
      if (cdnUrl != null && cdnUrl.isNotEmpty) {
        fileUrl =
            '$cdnUrl/avatars/$mediaId.${extension == 'png' ? 'png' : 'jpg'}';
      } else {
        final s3Domain = uploadUrl.split('//')[1].split('/')[0];
        fileUrl =
            'https://$s3Domain/avatars/$mediaId.${extension == 'png' ? 'png' : 'jpg'}';
      }

      // 4. Update picture standard attribute in Cognito and local state
      final updateResult = await ref
          .read(authControllerProvider.notifier)
          .updateProfile(avatarUrl: fileUrl);

      if (updateResult.success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật ảnh đại diện thành công!')),
          );
        }
      } else {
        throw Exception(
          updateResult.errorMessage ?? 'Cập nhật profile thất bại',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi upload: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<AuthResult> _updateProfileInfo({
    required String firstName,
    required String lastName,
    required String preferredUsername,
  }) async {
    return ref
        .read(authControllerProvider.notifier)
        .updateProfile(
          firstName: firstName,
          lastName: lastName,
          preferredUsername: preferredUsername,
        );
  }

  Future<UsernameAvailabilityResult> _checkUsernameAvailability(
    String username,
  ) {
    return ref.read(authServiceProvider).checkUsernameAvailability(username);
  }

  void _showEditProfileSheet({
    required String firstName,
    required String lastName,
    required String preferredUsername,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return EditProfileSheet(
          firstName: firstName,
          lastName: lastName,
          preferredUsername: preferredUsername,
          onSave: _updateProfileInfo,
          onCheckUsername: _checkUsernameAvailability,
          onSaved: () {},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch AuthState & FriendsState to rebuild reactively
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final friendsState = ref.watch(friendsControllerProvider);
    final requestCount = friendsState.requestCount;

    final firstName = authState?.firstName ?? '';
    final lastName = authState?.lastName ?? '';
    final fullNameList = [
      firstName,
      lastName,
    ].where((name) => name.trim().isNotEmpty).toList();
    final fullName = fullNameList.isEmpty
        ? 'Fidee User'
        : fullNameList.join(' ');
    final preferredUsername = authState?.preferredUsername ?? 'user';
    final tier = authState?.tier == UserTier.pro ? 'Premium' : 'Free';
    final since = authState?.since ?? '2026';
    final avatarUrl = authState?.avatarUrl;
    final initials = _getInitials(firstName, lastName);
    final visibleFriends = friendsState.friends
        .where((friend) => friend.id != friendsState.currentUserId)
        .toList(growable: false);

    // Apply Light Mode Theme manually to keep screen look clean & consistent with Figma light theme
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFFEF4050),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black54),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leadingWidth: 70,
          leading: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE9EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Color(0xFFEF4050),
                  size: 16,
                ),
              ),
            ),
          ),
          title: Text(
            'PROFILE',
            style: GoogleFonts.ericaOne(
              color: const Color(0xFFEF4050),
              fontSize: 32,
              fontWeight: FontWeight.w400,
              letterSpacing: 2.0,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Profile Header Gradient Card
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFAEBD), Color(0xFFFFF0F2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4050).withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar Container
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () => _pickAndUploadImage(context),
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                ),
                              ],
                              color: const Color(0xFFEF4050),
                              image: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: avatarUrl.startsWith('http')
                                          ? NetworkImage(avatarUrl)
                                                as ImageProvider
                                          : FileImage(File(avatarUrl)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        // Loading overlay
                        if (_isUploading)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black38,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Edit icon
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _pickAndUploadImage(context),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6E7E91),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    // User metadata info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              color: Color(0xFF151515),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tier,
                            style: const TextStyle(
                              color: Color(0xFFEF4050),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@$preferredUsername · SINCE $since',
                            style: const TextStyle(
                              color: Color(0xFF8D8D8D),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _showEditProfileSheet(
                                firstName: firstName,
                                lastName: lastName,
                                preferredUsername: preferredUsername,
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 15),
                              label: const Text('Sửa thông tin'),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFEF4050),
                                minimumSize: const Size(0, 34),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              FriendRequestSummaryBanner(
                count: requestCount,
                onOpen: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const FriendsDetailScreen(),
                    ),
                  );
                },
              ),
              if (requestCount > 0) const SizedBox(height: 16),

              // 2. Friends Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Friends (${visibleFriends.length})',
                    style: const TextStyle(
                      color: Color(0xFF151515),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const FriendsDetailScreen(),
                        ),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4050),
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFEF4050,
                                ).withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Chi tiết',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: FriendRequestBadge(count: requestCount),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Horizontal Scrolling List of Friends
              SizedBox(
                height: 110,
                child: friendsState.isInitialLoading
                    ? const _ProfileFriendsSkeleton()
                    : visibleFriends.isEmpty
                    ? Center(
                        child: Text(
                          'Chưa có bạn bè. Hãy kết nối thêm!',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: visibleFriends.length,
                        itemBuilder: (context, index) {
                          final friend = visibleFriends[index];
                          final friendInitials = friend.initials;

                          return Padding(
                            padding: const EdgeInsets.only(right: 18.0),
                            child: Column(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFFD4DA),
                                    image:
                                        friend.avatarUrl != null &&
                                            friend.avatarUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              friend.avatarUrl!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child:
                                      friend.avatarUrl == null ||
                                          friend.avatarUrl!.isEmpty
                                      ? Center(
                                          child: Text(
                                            friendInitials,
                                            style: const TextStyle(
                                              color: Color(0xFFEF4050),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 68,
                                  child: Text(
                                    friend.name,
                                    style: const TextStyle(
                                      color: Color(0xFF151515),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text(
                          'Đăng xuất',
                          style: TextStyle(
                            color: Color(0xFF151515),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: const Text(
                          'Bạn có chắc chắn muốn đăng xuất?',
                          style: TextStyle(color: Color(0xFF8D8D8D)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text(
                              'Hủy',
                              style: TextStyle(color: Color(0xFF8D8D8D)),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Đăng xuất',
                              style: TextStyle(
                                color: Color(0xFFEF4050),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref.read(authControllerProvider.notifier).signOut();
                      if (context.mounted) {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      }
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'ĐĂNG XUẤT',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE9EC),
                    foregroundColor: const Color(0xFFEF4050),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileFriendsSkeleton extends StatelessWidget {
  const _ProfileFriendsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(width: 18),
      itemBuilder: (context, index) {
        return Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD4DA),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 58,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        );
      },
    );
  }
}
