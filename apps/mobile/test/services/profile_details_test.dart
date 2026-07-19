import 'package:fidey_mobile/services/auth_service.dart';
import 'package:fidey_mobile/services/profile_details.dart';
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

    test('ignores a leading email token in displayName', () {
      final details = ProfileDetails.fromJson(<String, dynamic>{
        'displayName': 'nguyenminh110505@gmail.com Minh Nguyen',
        'username': 'ngxtm122',
        'plan': 'FREE',
      });

      expect(details.firstName, 'Minh');
      expect(details.lastName, 'Nguyen');
      expect(details.preferredUsername, 'ngxtm122');
    });

    test('prefers exact API name fields over displayName parsing', () {
      final details = ProfileDetails.fromJson(<String, dynamic>{
        'firstName': 'Minh 2',
        'lastName': 'Nguyen',
        'displayName': 'Minh 2 Nguyen',
        'plan': 'FREE',
      });

      expect(details.firstName, 'Minh 2');
      expect(details.lastName, 'Nguyen');
    });

    test('keeps legacy displayName fallback for older API responses', () {
      final details = ProfileDetails.fromJson(<String, dynamic>{
        'displayName': 'Minh 2 Nguyen',
        'plan': 'FREE',
      });

      expect(details.firstName, 'Minh');
      expect(details.lastName, '2 Nguyen');
    });
  });
}
