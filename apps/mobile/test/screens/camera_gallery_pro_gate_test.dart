import 'package:fidey_mobile/screens/camera_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'free gallery tap stops before permission when upgrade is declined',
    () async {
      final calls = <String>[];

      final opened = await runProGatedGalleryFlow(
        hasConfirmedPro: false,
        upgrade: () async {
          calls.add('upgrade');
          return false;
        },
        openPermissionAndPicker: () async {
          calls.add('permission');
        },
      );

      expect(opened, isFalse);
      expect(calls, <String>['upgrade']);
    },
  );

  test('confirmed upgrade opens permission and picker afterward', () async {
    final calls = <String>[];

    final opened = await runProGatedGalleryFlow(
      hasConfirmedPro: false,
      upgrade: () async {
        calls.add('upgrade');
        return true;
      },
      openPermissionAndPicker: () async {
        calls.add('permission');
      },
    );

    expect(opened, isTrue);
    expect(calls, <String>['upgrade', 'permission']);
  });

  test('confirmed Pro opens gallery without upgrade', () async {
    final calls = <String>[];

    final opened = await runProGatedGalleryFlow(
      hasConfirmedPro: true,
      upgrade: () async {
        calls.add('upgrade');
        return false;
      },
      openPermissionAndPicker: () async {
        calls.add('permission');
      },
    );

    expect(opened, isTrue);
    expect(calls, <String>['permission']);
  });
}
