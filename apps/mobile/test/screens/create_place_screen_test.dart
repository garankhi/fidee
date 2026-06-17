import 'dart:io';

import 'package:fidee_mobile/screens/create_place_screen.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _transparentPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(isTestMode: true);
}

void main() {
  testWidgets('shows share with friends toggle on by default', (tester) async {
    final photo = File('${Directory.systemTemp.path}/create-place-test.png');
    await photo.writeAsBytes(_transparentPng, flush: true);

    await tester.pumpWidget(
      MaterialApp(
        home: CreatePlaceScreen(
          photo: photo,
          lat: 10.7,
          lng: 106.6,
          accuracy: 8,
          mediaId: 'media-1',
          authService: _FakeAuthService(),
        ),
      ),
    );

    expect(find.text('Chia sẻ cho bạn bè'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isTrue);
  });
}
