import 'package:fidee_mobile/features/auth/auth_providers.dart';
import 'package:fidee_mobile/features/auth/friends_provider.dart';
import 'package:fidee_mobile/screens/camera_chat_inbox.dart';
import 'package:fidee_mobile/screens/profile_screen.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _HydratedAuthController extends AuthController {
  @override
  Future<AuthUiState> build() async {
    return const AuthUiState(
      authState: AuthState.authenticated,
      tier: UserTier.free,
      firstName: 'Nguyen',
      lastName: 'Minh',
      preferredUsername: 'minh.nguyen',
      avatarUrl: null,
      since: '2026',
    );
  }
}

class _EmptyFriendsController extends FriendsController {
  @override
  FriendsState build() => const FriendsState();
}

void main() {
  testWidgets('renders chat inbox rows like the reference conversation list', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CameraChatInboxScreen(
          threads: <CameraChatThread>[
            CameraChatThread(
              id: 'friend-1',
              name: 'Tạ',
              lastMessage: 'Hay quá',
              updatedAtLabel: 'vừa xong',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Trò chuyện'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('camera-chat-thread-friend-1')),
      findsOneWidget,
    );
    expect(find.text('Tạ'), findsOneWidget);
    expect(find.text('vừa xong'), findsOneWidget);
    expect(find.text('Hay quá'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('camera-bottom-section')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('camera-bottom-chat-button')),
      findsOneWidget,
    );
    final meAvatar = tester.widget<Container>(
      find.byKey(const ValueKey('camera-chat-me-avatar')),
    );
    expect(meAvatar.constraints?.maxWidth, 40);
    expect(meAvatar.constraints?.maxHeight, 40);
    final homeIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('camera-bottom-home-button')),
        matching: find.byIcon(Icons.home_filled),
      ),
    );
    final chatIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('camera-bottom-chat-button')),
        matching: find.byIcon(Icons.chat_bubble_rounded),
      ),
    );
    expect(homeIcon.color, Colors.grey);
    expect(chatIcon.color, Colors.white);
    expect(find.text('Lịch sử'), findsNothing);
    expect(find.byKey(const ValueKey('camera-chat-bottom-tab')), findsNothing);
  });

  testWidgets('shows an empty chat state when no comments exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CameraChatInboxScreen(threads: <CameraChatThread>[]),
      ),
    );

    expect(find.text('Chưa có tin nhắn'), findsOneWidget);
  });

  testWidgets('opens profile when tapping the current user avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_HydratedAuthController.new),
          friendsControllerProvider.overrideWith(_EmptyFriendsController.new),
        ],
        child: const MaterialApp(
          home: CameraChatInboxScreen(threads: <CameraChatThread>[]),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('camera-chat-me-avatar')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
