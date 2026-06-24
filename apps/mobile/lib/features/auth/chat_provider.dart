import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../services/appsync_realtime_service.dart';
import '../../services/user_chat_service.dart';
import 'auth_providers.dart';
import 'friend_realtime_provider.dart';

part 'chat_provider.g.dart';

class ChatInboxState {
  final List<UserChatConversation> conversations;
  final bool isLoading;
  final String? currentUserId;

  const ChatInboxState({
    this.conversations = const <UserChatConversation>[],
    this.isLoading = false,
    this.currentUserId,
  });

  int get totalUnreadCount => conversations.fold(
    0,
    (total, conversation) => total + conversation.unreadCount,
  );

  ChatInboxState copyWith({
    List<UserChatConversation>? conversations,
    bool? isLoading,
    String? currentUserId,
  }) {
    return ChatInboxState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }
}

class ChatThreadState {
  final List<UserChatMessage> messages;
  final bool isLoading;
  final bool isTyping;

  const ChatThreadState({
    this.messages = const <UserChatMessage>[],
    this.isLoading = false,
    this.isTyping = false,
  });

  ChatThreadState copyWith({
    List<UserChatMessage>? messages,
    bool? isLoading,
    bool? isTyping,
  }) {
    return ChatThreadState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

@Riverpod(keepAlive: true)
UserChatService userChatService(UserChatServiceRef ref) {
  final authService = ref.watch(authServiceProvider);
  return UserChatService(authService);
}

@Riverpod(keepAlive: true)
class ChatInboxController extends _$ChatInboxController {
  late UserChatService _service;

  @override
  ChatInboxState build() {
    _service = ref.watch(userChatServiceProvider);
    Future.microtask(load);
    return const ChatInboxState(isLoading: true);
  }

  Future<void> load({bool silent = false}) async {
    final authService = ref.read(authServiceProvider);
    final userId = await authService.getCurrentUserSub();
    if (userId == null || userId.isEmpty) {
      state = const ChatInboxState();
      return;
    }
    final userChanged =
        state.currentUserId != null && state.currentUserId != userId;
    if (userChanged || !silent) {
      state = ChatInboxState(isLoading: true, currentUserId: userId);
    }
    final conversations = await _service.fetchConversations();
    state = ChatInboxState(
      conversations: conversations,
      isLoading: false,
      currentUserId: userId,
    );
  }

  Future<String?> openDirectConversation(String targetUserId) async {
    final conversationId = await _service.createDirectConversation(
      targetUserId,
    );
    if (conversationId != null) {
      unawaited(load(silent: true));
    }
    return conversationId;
  }

  void markConversationRead(String conversationId) {
    state = state.copyWith(
      conversations: state.conversations
          .map(
            (conversation) => conversation.id == conversationId
                ? conversation.copyWith(unreadCount: 0)
                : conversation,
          )
          .toList(growable: false),
    );
  }

  void applyRealtimeEvent(ChatRealtimeEvent event) {
    if (event.type == 'MESSAGE_CREATED' && event.message != null) {
      final message = UserChatMessage(
        id: event.message!.id,
        conversationId: event.message!.conversationId,
        senderId: event.message!.senderId,
        clientMessageId: event.message!.clientMessageId,
        body: event.message!.body,
        status: event.message!.status,
        createdAt: event.message!.createdAt,
      );
      final next =
          state.conversations
              .map((conversation) {
                if (conversation.id != message.conversationId) {
                  return conversation;
                }
                return conversation.copyWith(
                  lastMessage: message,
                  unreadCount: message.senderId == state.currentUserId
                      ? conversation.unreadCount
                      : conversation.unreadCount + 1,
                  updatedAt: message.createdAt,
                );
              })
              .toList(growable: false)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = state.copyWith(conversations: next);
    } else if (event.type == 'PRESENCE_CHANGED') {
      unawaited(load(silent: true));
    }
  }
}

final chatThreadControllerProvider =
    AutoDisposeNotifierProviderFamily<
      ChatThreadController,
      ChatThreadState,
      String
    >(ChatThreadController.new);

class ChatThreadController
    extends AutoDisposeFamilyNotifier<ChatThreadState, String> {
  late UserChatService _service;
  late String conversationId;

  @override
  ChatThreadState build(String arg) {
    conversationId = arg;
    _service = ref.watch(userChatServiceProvider);
    Future.microtask(load);
    return const ChatThreadState(isLoading: true);
  }

  Future<void> load() async {
    final messages = await _service.fetchMessages(conversationId);
    state = ChatThreadState(messages: messages, isLoading: false);
    final lastMessage = messages.isEmpty ? null : messages.last;
    if (lastMessage != null) {
      ref
          .read(chatInboxControllerProvider.notifier)
          .markConversationRead(conversationId);
      unawaited(
        _service.markRead(
          conversationId: conversationId,
          messageId: lastMessage.id,
        ),
      );
    }
  }

  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final authService = ref.read(authServiceProvider);
    final senderId = await authService.getCurrentUserSub() ?? '';
    final clientMessageId = _service.createClientMessageId();
    final pending = UserChatMessage(
      id: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      clientMessageId: clientMessageId,
      body: trimmed,
      status: 'SENDING',
      createdAt: DateTime.now(),
      isPending: true,
    );
    state = state.copyWith(messages: [...state.messages, pending]);
    final sent = await _service.sendMessage(
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      body: trimmed,
    );
    if (sent == null) return;
    state = state.copyWith(
      messages: state.messages
          .map(
            (message) =>
                message.clientMessageId == clientMessageId ? sent : message,
          )
          .toList(growable: false),
    );
    unawaited(
      ref.read(chatInboxControllerProvider.notifier).load(silent: true),
    );
  }

  void applyRealtimeEvent(ChatRealtimeEvent event) {
    if (event.conversationId != conversationId) return;
    if (event.type == 'MESSAGE_CREATED' && event.message != null) {
      final incoming = UserChatMessage(
        id: event.message!.id,
        conversationId: event.message!.conversationId,
        senderId: event.message!.senderId,
        clientMessageId: event.message!.clientMessageId,
        body: event.message!.body,
        status: event.message!.status,
        createdAt: event.message!.createdAt,
      );
      final exists = state.messages.any(
        (message) =>
            message.id == incoming.id ||
            message.clientMessageId == incoming.clientMessageId,
      );
      if (!exists) {
        state = state.copyWith(messages: [...state.messages, incoming]);
      }
      unawaited(
        _service.markRead(
          conversationId: conversationId,
          messageId: incoming.id,
        ),
      );
    } else if (event.type == 'TYPING' && event.typing != null) {
      state = state.copyWith(isTyping: event.typing!.isTyping);
    }
  }

  Future<void> sendTyping(bool isTyping) {
    return _service.sendTyping(
      conversationId: conversationId,
      isTyping: isTyping,
    );
  }
}

final chatRealtimeControllerProvider = Provider<ChatRealtimeController>((ref) {
  final controller = ChatRealtimeController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

final lastChatRealtimeEventProvider = StateProvider<ChatRealtimeEvent?>(
  (ref) => null,
);

class ChatRealtimeController {
  ChatRealtimeController(this._ref);

  final Ref _ref;
  StreamSubscription<ChatRealtimeEvent>? _subscription;
  Timer? _heartbeatTimer;
  String? _connectedUserId;

  Future<void> connect() async {
    final authService = _ref.read(authServiceProvider);
    final targetUserId = await authService.getCurrentUserSub();
    if (targetUserId == null || targetUserId.isEmpty) return;
    if (_subscription != null && _connectedUserId == targetUserId) return;

    await _subscription?.cancel();
    _connectedUserId = targetUserId;
    final service = _ref.read(appSyncRealtimeServiceProvider);
    _subscription = service
        .subscribeToChatEvents(targetUserId: targetUserId)
        .listen(
          (event) {
            _ref.read(lastChatRealtimeEventProvider.notifier).state = event;
            if (event.type == 'MESSAGE_CREATED' && event.message != null) {
              unawaited(
                _ref
                    .read(userChatServiceProvider)
                    .markDelivered(
                      conversationId: event.message!.conversationId,
                      messageId: event.message!.id,
                    ),
              );
            }
            _ref
                .read(chatInboxControllerProvider.notifier)
                .applyRealtimeEvent(event);
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Chat realtime subscription error: $error');
          },
        );
    _startHeartbeat();
  }

  Future<void> disconnect() async {
    _connectedUserId = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    _connectedUserId = null;
    _heartbeatTimer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _startHeartbeat() {
    final service = _ref.read(userChatServiceProvider);
    unawaited(service.heartbeat());
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(service.heartbeat()),
    );
  }
}
