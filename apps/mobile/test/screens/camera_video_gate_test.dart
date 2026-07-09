import 'package:fidey_mobile/screens/camera_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canRecordVideo requires a ready camera only', () {
    expect(canRecordVideo(cameraReady: false), isFalse);
    expect(canRecordVideo(cameraReady: true), isTrue);
  });
}
