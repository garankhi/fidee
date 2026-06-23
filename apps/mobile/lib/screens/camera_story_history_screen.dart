import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/camera_checkin_feed_provider.dart';
import '../features/auth/friends_provider.dart';
import 'camera_audience_selector.dart';
import 'camera_bottom_section.dart';
import 'camera_checkin_feed.dart';

class CameraStoryHistoryScreen extends ConsumerWidget {
  const CameraStoryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(cameraCheckinFeedControllerProvider);
    final feedController = ref.read(cameraCheckinFeedControllerProvider.notifier);
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final friendsState = ref.watch(friendsControllerProvider);
    final currentUserInitials =
        (authState?.firstName?.trim().isNotEmpty ?? false)
        ? authState!.firstName!.trim().characters.first.toUpperCase()
        : 'B';

    return Scaffold(
      backgroundColor: const Color(0xFF201B18),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              top: 72,
              bottom: 76,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.pixels >=
                          notification.metrics.maxScrollExtent - 280 &&
                      feedState.hasMore &&
                      !feedState.isLoadingMore) {
                    unawaited(feedController.loadMore());
                  }
                  return false;
                },
                child: CameraStoryHistoryGrid(
                  items: feedState.items,
                  isLoading: feedState.isLoading,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: CameraBottomSection(
                activeTab: CameraBottomTab.history,
                showHistory: false,
                onHomeTap: () => Navigator.pop(context),
                onHistoryTap: () {},
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: CameraAudienceSelector(
                  selectedAudience: feedState.audience,
                  friends: friendsState.friends,
                  currentUserAvatarUrl: authState?.avatarUrl,
                  currentUserInitials: currentUserInitials,
                  onSelected: (audience) {
                    unawaited(feedController.selectAudience(audience));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
