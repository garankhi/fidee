import 'package:fidey_mobile/services/upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detectUploadContentType supports video files', () {
    expect(detectUploadContentType('clip.mp4'), 'video/mp4');
    expect(detectUploadContentType('clip.MOV'), 'video/quicktime');
    expect(detectUploadContentType('photo.jpg'), 'image/jpeg');
  });

  test('isVideoUploadTooLarge enforces 20MB video limit only for videos', () {
    expect(
      isVideoUploadTooLarge(
        contentType: 'video/mp4',
        byteLength: maxVideoUploadBytes + 1,
      ),
      isTrue,
    );
    expect(
      isVideoUploadTooLarge(
        contentType: 'video/mp4',
        byteLength: maxVideoUploadBytes,
      ),
      isFalse,
    );
    expect(
      isVideoUploadTooLarge(
        contentType: 'image/jpeg',
        byteLength: maxVideoUploadBytes + 1,
      ),
      isFalse,
    );
  });
}
