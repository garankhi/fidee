import 'dart:typed_data';

import 'package:fidee_mobile/screens/gallery_preview_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _transparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

void main() {
  Uint8List thumbnail() => Uint8List.fromList(_transparentPng);

  Widget buildButton(List<Uint8List> thumbnails) {
    return MaterialApp(
      home: Scaffold(
        body: GalleryPreviewButton(thumbnails: thumbnails, onTap: () {}),
      ),
    );
  }

  testWidgets('shows one icon placeholder when no gallery thumbnails are available', (
    tester,
  ) async {
    await tester.pumpWidget(buildButton(const <Uint8List>[]));

    expect(find.byKey(const ValueKey('gallery-preview-placeholder')), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-preview-back-photo')), findsNothing);
    expect(find.byKey(const ValueKey('gallery-preview-front-photo')), findsNothing);
  });

  testWidgets('shows only the back thumbnail when exactly one gallery photo exists', (
    tester,
  ) async {
    await tester.pumpWidget(buildButton(<Uint8List>[thumbnail()]));

    expect(find.byKey(const ValueKey('gallery-preview-back-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-preview-front-photo')), findsNothing);
    expect(find.byKey(const ValueKey('gallery-preview-placeholder')), findsNothing);
  });

  testWidgets('shows stacked back and front thumbnails when two photos exist', (
    tester,
  ) async {
    await tester.pumpWidget(buildButton(<Uint8List>[thumbnail(), thumbnail()]));

    expect(find.byKey(const ValueKey('gallery-preview-back-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-preview-front-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-preview-placeholder')), findsNothing);
  });
}
