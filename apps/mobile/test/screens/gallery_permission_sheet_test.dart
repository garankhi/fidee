import 'package:fidee_mobile/screens/gallery_permission_sheet.dart';
import 'package:fidee_mobile/services/gallery_permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<GalleryPermissionAction?> showPermissionSheet(
    WidgetTester tester,
    GalleryPermissionStatus status,
  ) async {
    GalleryPermissionAction? selectedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    selectedAction =
                        await showModalBottomSheet<GalleryPermissionAction>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) =>
                              GalleryPermissionSheet(status: status),
                        );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    return selectedAction;
  }

  testWidgets('shows first-time access choices', (tester) async {
    await showPermissionSheet(tester, GalleryPermissionStatus.notDetermined);

    expect(find.text('Chia sẻ ảnh từ thư viện'), findsOneWidget);
    expect(find.text('Chia sẻ tất cả ảnh'), findsOneWidget);
    expect(find.text('Chọn ảnh'), findsOneWidget);
    expect(find.text('Không chia sẻ'), findsOneWidget);
  });

  testWidgets('shows limited access management choices', (tester) async {
    await showPermissionSheet(tester, GalleryPermissionStatus.limited);

    expect(
      find.text('Bạn đang chỉ chia sẻ một số ảnh với Fidee'),
      findsOneWidget,
    );
    expect(find.text('Chọn thêm ảnh'), findsOneWidget);
    expect(find.text('Chia sẻ tất cả ảnh'), findsOneWidget);
    expect(find.text('Không chia sẻ'), findsOneWidget);
  });

  testWidgets('returns request access when share all is tapped first time', (
    tester,
  ) async {
    GalleryPermissionAction? selectedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  selectedAction =
                      await showModalBottomSheet<GalleryPermissionAction>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const GalleryPermissionSheet(
                          status: GalleryPermissionStatus.notDetermined,
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
    await tester.tap(find.text('Chia sẻ tất cả ảnh'));
    await tester.pumpAndSettle();

    expect(selectedAction, GalleryPermissionAction.requestAccess);
  });

  testWidgets('returns select more from limited access sheet', (tester) async {
    GalleryPermissionAction? selectedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  selectedAction =
                      await showModalBottomSheet<GalleryPermissionAction>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const GalleryPermissionSheet(
                          status: GalleryPermissionStatus.limited,
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
    await tester.tap(find.text('Chọn thêm ảnh'));
    await tester.pumpAndSettle();

    expect(selectedAction, GalleryPermissionAction.selectMore);
  });
}
