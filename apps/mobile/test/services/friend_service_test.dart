import 'dart:convert';

import 'package:fidee_mobile/config.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:fidee_mobile/services/friend_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeAuthService extends AuthService {
  FakeAuthService(this.token) : super(isTestMode: true);

  final String? token;

  @override
  Future<String?> getToken() async => token;
}

void main() {
  group('FriendService', () {
    test('fetchFriendRequests parses request profiles from /friends/requests', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), '${Config.apiBaseUrl}/friends/requests');
        expect(request.headers['Authorization'], 'token-123');

        return http.Response(
          jsonEncode({
            'requests': [
              {
                'id': 'user-1',
                'name': 'Minh Nguyen',
                'username': 'minh',
                'avatarUrl': 'https://cdn.example/avatar.png',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = FriendService(FakeAuthService('token-123'), client: client);

      final requests = await service.fetchFriendRequests();

      expect(requests, hasLength(1));
      expect(requests.single.id, 'user-1');
      expect(requests.single.name, 'Minh Nguyen');
      expect(requests.single.handle, 'minh');
      expect(requests.single.avatarUrl, 'https://cdn.example/avatar.png');
    });

    test('sendFriendRequest posts targetUserId to /friends/request', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '${Config.apiBaseUrl}/friends/request');
        expect(request.headers['Authorization'], 'token-123');
        expect(request.headers['Content-Type'], 'application/json');
        expect(jsonDecode(request.body), {'targetUserId': 'user-2'});
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final service = FriendService(FakeAuthService('token-123'), client: client);

      expect(await service.sendFriendRequest('user-2'), isTrue);
    });

    test('acceptFriend posts targetUserId to /friends/accept', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '${Config.apiBaseUrl}/friends/accept');
        expect(jsonDecode(request.body), {'targetUserId': 'user-2'});
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final service = FriendService(FakeAuthService('token-123'), client: client);

      expect(await service.acceptFriend('user-2'), isTrue);
    });

    test('declineFriend posts targetUserId to /friends/decline', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '${Config.apiBaseUrl}/friends/decline');
        expect(jsonDecode(request.body), {'targetUserId': 'user-2'});
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final service = FriendService(FakeAuthService('token-123'), client: client);

      expect(await service.declineFriend('user-2'), isTrue);
    });

    test('unfriend posts targetUserId to /friends/unfriend', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '${Config.apiBaseUrl}/friends/unfriend');
        expect(jsonDecode(request.body), {'targetUserId': 'user-2'});
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final service = FriendService(FakeAuthService('token-123'), client: client);

      expect(await service.unfriend('user-2'), isTrue);
    });

    test('action methods return false and skip HTTP when token is missing', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{}', 500);
      });

      final service = FriendService(FakeAuthService(null), client: client);

      expect(await service.sendFriendRequest('user-2'), isFalse);
      expect(await service.acceptFriend('user-2'), isFalse);
      expect(await service.declineFriend('user-2'), isFalse);
      expect(await service.unfriend('user-2'), isFalse);
      expect(called, isFalse);
    });
    test('searchUsersByUsername gets matching users from /friends/search', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), '${Config.apiBaseUrl}/friends/search?username=minh');
        expect(request.headers['Authorization'], 'token-123');

        return http.Response(
          jsonEncode({
            'users': [
              {
                'id': 'user-2',
                'name': 'Minh Tran',
                'username': 'minh',
                'avatarUrl': 'https://cdn.example/minh.png',
                'relationStatus': 'NONE',
                'canRequest': true,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = FriendService(FakeAuthService('token-123'), client: client);

      final results = await service.searchUsersByUsername(' Minh ');

      expect(results, hasLength(1));
      expect(results.single.profile.id, 'user-2');
      expect(results.single.profile.name, 'Minh Tran');
      expect(results.single.profile.handle, 'minh');
      expect(results.single.relationStatus, FriendRelationStatus.none);
      expect(results.single.canRequest, isTrue);
    });

    test('hideFriend posts targetUserId to /friends/hide', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '${Config.apiBaseUrl}/friends/hide');
        expect(jsonDecode(request.body), {'targetUserId': 'user-2'});
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final service = FriendService(FakeAuthService('token-123'), client: client);

      expect(await service.hideFriend('user-2'), isTrue);
    });

    test('blockFriend posts targetUserId to /friends/block', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '${Config.apiBaseUrl}/friends/block');
        expect(jsonDecode(request.body), {'targetUserId': 'user-2'});
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final service = FriendService(FakeAuthService('token-123'), client: client);

      expect(await service.blockFriend('user-2'), isTrue);
    });
  });
}
