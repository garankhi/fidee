import 'package:fidey_mobile/features/auth/auth_providers.dart';
import 'package:fidey_mobile/main.dart';
import 'package:fidey_mobile/services/auth_service.dart';
import 'package:fidey_mobile/services/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps native splash while auth is initially loading', () {
    final keepSplash = shouldKeepNativeSplash(
      const AsyncLoading<AuthUiState>(),
      AsyncData<LocationService>(LocationService()),
    );

    expect(keepSplash, isTrue);
  });

  test('keeps native splash while location is initially loading', () {
    final keepSplash = shouldKeepNativeSplash(
      const AsyncData<AuthUiState>(
        AuthUiState(authState: AuthState.unauthenticated),
      ),
      const AsyncLoading<LocationService>(),
    );

    expect(keepSplash, isTrue);
  });

  test('releases native splash when auth and location have resolved', () {
    final keepSplash = shouldKeepNativeSplash(
      const AsyncData<AuthUiState>(
        AuthUiState(authState: AuthState.unauthenticated),
      ),
      AsyncData<LocationService>(LocationService()),
    );

    expect(keepSplash, isFalse);
  });
}
