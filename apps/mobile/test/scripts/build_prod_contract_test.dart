import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String script;

  setUpAll(() {
    script = File(
      'scripts/build-prod.ps1',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('requires an explicit stack name and build number', () {
    expect(
      script,
      contains(
        r'[Parameter(Mandatory = $true)]'
        '\n'
        r'  [ValidatePattern',
      ),
    );
    expect(script, contains(r"[ValidatePattern('^Fidee-(dev|prod)$')]"));
    expect(script, contains(r'[string]$StackName,'));
    expect(script, isNot(contains(r"[string]$StackName = 'Fidee-dev'")));
    expect(script, contains(r'[int]$BuildNumber,'));
  });

  test('rejects a production release against dev without explicit override', () {
    expect(script, contains(r'[switch]$AllowDevBackendForProductionRelease'));
    expect(script, contains(r"$StackName -eq 'Fidee-dev'"));
    expect(
      script,
      contains(r'-not $AllowDevBackendForProductionRelease.IsPresent'),
    );
    expect(
      script,
      contains(
        "throw 'Refusing a Play production build against Fidee-dev without explicit override.'",
      ),
    );
  });

  test('reads Google Web client id from the selected stack', () {
    expect(
      script,
      contains(
        "Add-DartDefine 'GOOGLE_WEB_CLIENT_ID' (Get-StackOutput 'GoogleWebClientId')",
      ),
    );
  });

  test('does not use stale local CDK outputs as an API fallback', () {
    expect(script, isNot(contains('cdk-outputs-prod.json')));
    expect(
      script,
      contains(
        r'& aws cloudformation describe-stacks `'
        '\n'
        r'    --stack-name $StackName',
      ),
    );
  });
}
