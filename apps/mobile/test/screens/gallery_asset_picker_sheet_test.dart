import 'dart:typed_data';

import 'package:fidee_mobile/screens/gallery_asset_picker_sheet.dart';
import 'package:fidee_mobile/services/gallery_asset_picker_service.dart';
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

void main() {
  testWidgets('returns selected asset path', (tester) async {
    String? selectedPath;
    final item = GalleryAssetPickerItem(
      id: 'asset-1',
      title: 'first.jpg',
      thumbnail: Uint8List.fromList(_transparentPng),
      loadPath: () async => 'D:/tmp/first.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  selectedPath = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => GalleryAssetPickerSheet(
                      loadAssets: () async => <GalleryAssetPickerItem>[item],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gallery-asset-asset-1')));
    await tester.pumpAndSettle();

    expect(selectedPath, 'D:/tmp/first.jpg');
  });

  testWidgets('shows empty state when no accessible images exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GalleryAssetPickerSheet(
            loadAssets: () async => const <GalleryAssetPickerItem>[],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Không có ảnh nào để chọn'), findsOneWidget);
  });
}
