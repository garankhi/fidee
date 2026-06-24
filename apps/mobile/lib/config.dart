import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  // Configured via AWS CDK outputs
  static const String cognitoUserPoolId = 'ap-southeast-1_KSHDSpl6f';
  static const String cognitoClientId = '35jeemfqql648mt950s6bs3qli';
  static const String apiBaseUrl = 'https://api.fidee.site';
  static const String awsRegion = 'ap-southeast-1';
  static const String appSyncGraphqlUrl =
      'https://3mweqov3bvfr5npo34mwyosdoy.appsync-api.ap-southeast-1.amazonaws.com/graphql';
  static const String appSyncRealtimeUrl =
      'wss://3mweqov3bvfr5npo34mwyosdoy.appsync-realtime-api.ap-southeast-1.amazonaws.com/graphql';

  static const String revenueCatEntitlementPro = 'pro';
  static const String revenueCatMonthlyProductId = 'fidee_pro_monthly';
  static const String revenueCatYearlyProductId = 'fidee_pro_yearly';

  static const String _defaultGoongStyleUrl =
      'https://tiles.goong.io/assets/goong_map_web.json';
  static const String _goongMaptilesKeyDefine = String.fromEnvironment(
    'GOONG_MAPTILES_KEY',
  );
  static const String _goongStyleUrlDefine = String.fromEnvironment(
    'GOONG_STYLE_URL',
  );
  static const String _goongApiKeyDefine = String.fromEnvironment(
    'GOONG_API_KEY',
  );
  static const String _revenueCatIosApiKeyDefine = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
  );
  static const String _revenueCatAndroidApiKeyDefine = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );

  static String get goongMaptilesKey {
    return _envOrDefine('GOONG_MAPTILES_KEY', _goongMaptilesKeyDefine);
  }

  static String get goongApiKey {
    return _envOrDefine('GOONG_API_KEY', _goongApiKeyDefine);
  }

  static String get goongStyleUrl {
    return _envOrDefine(
      'GOONG_STYLE_URL',
      _goongStyleUrlDefine,
      defaultValue: _defaultGoongStyleUrl,
    );
  }

  static String get revenueCatIosApiKey {
    return _envOrDefine('REVENUECAT_IOS_API_KEY', _revenueCatIosApiKeyDefine);
  }

  static String get revenueCatAndroidApiKey {
    return _envOrDefine(
      'REVENUECAT_ANDROID_API_KEY',
      _revenueCatAndroidApiKeyDefine,
    );
  }

  static String _envOrDefine(
    String name,
    String defineValue, {
    String defaultValue = '',
  }) {
    final runtimeValue = dotenv.isInitialized ? dotenv.env[name]?.trim() : null;
    if (runtimeValue != null && runtimeValue.isNotEmpty) {
      return runtimeValue;
    }

    final compileTimeValue = defineValue.trim();
    if (compileTimeValue.isNotEmpty) {
      return compileTimeValue;
    }

    return defaultValue;
  }

  static bool hasGoongMaptilesKey([String? key]) {
    return (key ?? goongMaptilesKey).trim().isNotEmpty;
  }

  static bool hasGoongApiKey([String? key]) {
    return (key ?? goongApiKey).trim().isNotEmpty;
  }

  static String goongStyleUrlWithKey({String? maptilesKey, String? styleUrl}) {
    final key = (maptilesKey ?? goongMaptilesKey).trim();
    final uri = Uri.parse(styleUrl ?? goongStyleUrl);
    return uri
        .replace(queryParameters: {...uri.queryParameters, 'api_key': key})
        .toString();
  }
}
