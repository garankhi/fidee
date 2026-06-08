import 'package:fidee_mobile/services/auth_service.dart';
import 'package:fidee_mobile/services/profile_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileDetails', () {
    test('maps backend profile response into profile fields', () {
      final details = ProfileDetails.fromJson(<String, dynamic>{
        'displayName': 'Nguyen Minh',
        'username': 'minh.nguyen',
        'avatarUrl': 'https://cdn.example.com/avatar.jpg',
        'plan': 'PRO',
        'createdAt': '2026-01-15T08:30:00.000Z',
      });

      expect(details.firstName, 'Nguyen');
      expect(details.lastName, 'Minh');
      expect(details.preferredUsername, 'minh.nguyen');
      expect(details.avatarUrl, 'https://cdn.example.com/avatar.jpg');
      expect(details.tier, UserTier.pro);
      expect(details.since, '2026');
    });

    test('keeps nullable fields empty when backend omits optional values', () {
      final details = ProfileDetails.fromJson(<String, dynamic>{
        'displayName': 'User',
        'plan': 'FREE',
      });

      expect(details.firstName, 'User');
      expect(details.lastName, isNull);
      expect(details.preferredUsername, isNull);
      expect(details.avatarUrl, isNull);
      expect(details.tier, UserTier.free);
      expect(details.since, isNull);
    });
  });
}
