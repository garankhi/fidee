import 'package:fidey_mobile/features/auth/auth_providers.dart';
import 'package:fidey_mobile/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthUiState', () {
    test('fromService exposes profile fields for profile completion', () async {
      final service = AuthService(isTestMode: true);
      await service.initialize();
      await service.completeProfile('Minh', 'Nguyen', 'minh.nguyen');

      final state = AuthUiState.fromService(service);

      expect(state.firstName, 'Minh');
      expect(state.lastName, 'Nguyen');
      expect(state.preferredUsername, 'minh.nguyen');

      await service.updateProfile(
        avatarUrl: 'https://cdn.example.com/avatar.jpg',
      );
      await service.applyProfileDetailsForTesting(<String, dynamic>{
        'displayName': 'Minh Nguyen',
        'username': 'minh.nguyen',
        'avatarUrl': 'https://cdn.example.com/avatar.jpg',
        'bio': 'Coffee hunter',
        'plan': 'PRO',
        'createdAt': '2026-01-15T08:30:00.000Z',
      });

      final updatedState = AuthUiState.fromService(service);
      expect(updatedState.avatarUrl, 'https://cdn.example.com/avatar.jpg');
      expect(updatedState.bio, 'Coffee hunter');
      expect(updatedState.since, '2026');
      expect(updatedState.tier, UserTier.pro);
    });

    test('single-part display name with username counts as complete profile', () async {
      final service = AuthService(isTestMode: true);
      await service.initialize();

      await service.applyProfileDetailsForTesting(<String, dynamic>{
        'displayName': 'Tydapchai',
        'username': 'tydapchai',
        'plan': 'FREE',
      });

      expect(service.hasCompleteProfileForTesting, isTrue);

      final state = AuthUiState.fromService(service);
      expect(state.firstName, 'Tydapchai');
      expect(state.lastName, '');
      expect(state.preferredUsername, 'tydapchai');
    });
  });
}
