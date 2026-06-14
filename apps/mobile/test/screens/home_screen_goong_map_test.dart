import 'package:fidee_mobile/screens/home_screen.dart';
import 'package:fidee_mobile/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(isOptional: true);
  });

  tearDown(() {
    dotenv.loadFromString(isOptional: true);
  });

  testWidgets('shows a non-blocking Goong key fallback when key is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: HomeScreen(locationService: LocationService()),
        ),
      ),
    );

    expect(find.text('GOONG_MAPTILES_KEY chưa được cấu hình.'), findsOneWidget);
  });
}
