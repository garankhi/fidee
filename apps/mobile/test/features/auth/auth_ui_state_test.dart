import 'package:fidee_mobile/features/auth/auth_providers.dart';
import 'package:fidee_mobile/services/auth_service.dart';
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
    });
  });
}
