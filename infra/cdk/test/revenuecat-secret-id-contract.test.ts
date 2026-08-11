import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

const stackSource = readFileSync(
  fileURLToPath(new URL('../lib/fidee-stack.ts', import.meta.url)),
  'utf8',
);

describe('RevenueCat secret runtime identifier', () => {
  it('passes the secret name instead of the imported partial ARN', () => {
    expect(stackSource).toMatch(
      /REVENUECAT_SERVER_SECRET_ARN:\s*revenueCatServerSecret\.secretName/,
    );
    expect(stackSource).not.toMatch(
      /REVENUECAT_SERVER_SECRET_ARN:\s*revenueCatServerSecret\.secretArn/,
    );
  });
});
