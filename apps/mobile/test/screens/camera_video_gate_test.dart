import 'package:fidee_mobile/screens/camera_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canRecordVideo requires Pro and ready camera', () {
    expect(canRecordVideo(isPro: false, cameraReady: true), isFalse);
    expect(canRecordVideo(isPro: true, cameraReady: false), isFalse);
    expect(canRecordVideo(isPro: true, cameraReady: true), isTrue);
  });
}
