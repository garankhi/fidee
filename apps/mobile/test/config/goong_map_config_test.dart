import 'package:fidee_mobile/config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(isOptional: true);
  });

  tearDown(() {
    dotenv.loadFromString(isOptional: true);
  });

  group('Config.goongStyleUrlWithKey', () {
    test('adds the maptiles key to the default Goong street style URL', () {
      expect(
        Config.goongStyleUrlWithKey(maptilesKey: 'test-key'),
        'https://tiles.goong.io/assets/goong_map_web.json?api_key=test-key',
      );
    });

    test('preserves existing query parameters when adding api_key', () {
      expect(
        Config.goongStyleUrlWithKey(
          maptilesKey: 'test-key',
          styleUrl: 'https://tiles.goong.io/assets/goong_map_dark.json?lang=vi',
        ),
        'https://tiles.goong.io/assets/goong_map_dark.json?lang=vi&api_key=test-key',
      );
    });

    test('reports whether a runtime maptiles key is configured', () {
      expect(Config.hasGoongMaptilesKey('  test-key  '), isTrue);
      expect(Config.hasGoongMaptilesKey('   '), isFalse);
    });

    test('reads the Goong maptiles key from runtime dotenv', () {
      dotenv.loadFromString(envString: 'GOONG_MAPTILES_KEY= runtime-key ');

      expect(Config.goongMaptilesKey, 'runtime-key');
      expect(Config.hasGoongMaptilesKey(), isTrue);
      expect(
        Config.goongStyleUrlWithKey(),
        'https://tiles.goong.io/assets/goong_map_web.json?api_key=runtime-key',
      );
    });

    test('reads the Goong style URL from runtime dotenv', () {
      dotenv.loadFromString(
        envString:
            'GOONG_MAPTILES_KEY=test-key\nGOONG_STYLE_URL=https://tiles.goong.io/assets/custom.json?lang=vi',
      );

      expect(
        Config.goongStyleUrl,
        'https://tiles.goong.io/assets/custom.json?lang=vi',
      );
      expect(
        Config.goongStyleUrlWithKey(),
        'https://tiles.goong.io/assets/custom.json?lang=vi&api_key=test-key',
      );
    });
  });
}
