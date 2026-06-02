import { describe, it, expect } from 'vitest';
import { extractAuth, maskPhone, maskEmail, requireGroup, requireAdmin } from './auth';
import { APIGatewayProxyEvent } from 'aws-lambda';

const mockEventWithClaims = (
  claims: Record<string, string | undefined>,
): APIGatewayProxyEvent =>
  ({
    requestContext: {
      authorizer: { claims },
    },
  }) as unknown as APIGatewayProxyEvent;

describe('maskPhone', () => {
  it('masks middle digits', () => {
    expect(maskPhone('+84912345678')).toBe('+84912***678');
  });

  it('handles short numbers', () => {
    expect(maskPhone('+841')).toBe('***');
  });
});

describe('maskEmail', () => {
  it('masks email local part', () => {
    expect(maskEmail('user@example.com')).toBe('us***@example.com');
  });
});

describe('extractAuth', () => {
  it('extracts sub, phone, email from claims', async () => {
    const event = mockEventWithClaims({
      sub: 'user-123',
      phone_number: '+84912345678',
      email: 'user@example.com',
      'cognito:groups': 'Users',
    });
    const auth = await extractAuth(event);
    expect(auth.sub).toBe('user-123');
    expect(auth.phone).toBe('+84912345678');
    expect(auth.email).toBe('user@example.com');
    expect(auth.groups).toEqual(['Users']);
  });

  it('defaults to Users group when no groups claim', async () => {
    const event = mockEventWithClaims({
      sub: 'user-123',
      phone_number: '+84912345678',
    });
    const auth = await extractAuth(event);
    expect(auth.groups).toEqual(['Users']);
  });

  it('parses multiple groups', async () => {
    const event = mockEventWithClaims({
      sub: 'admin-1',
      'cognito:groups': 'Admins,Moderators',
    });
    const auth = await extractAuth(event);
    expect(auth.groups).toEqual(['Admins', 'Moderators']);
  });

  it('throws when sub is missing', async () => {
    const event = mockEventWithClaims({});
    await expect(extractAuth(event)).rejects.toThrow('Missing auth context');
  });
});

describe('requireGroup', () => {
  it('passes when user is in required group', () => {
    const auth = { sub: '1', phone: undefined, email: undefined, groups: ['Admins'] };
    expect(() => requireGroup(auth, 'Admins')).not.toThrow();
  });

  it('throws when user is not in required group', () => {
    const auth = { sub: '1', phone: undefined, email: undefined, groups: ['Users'] };
    expect(() => requireGroup(auth, 'Admins')).toThrow('Forbidden');
  });
});

describe('requireAdmin', () => {
  it('passes for Admins', () => {
    const auth = { sub: '1', phone: undefined, email: undefined, groups: ['Admins'] };
    expect(() => requireAdmin(auth)).not.toThrow();
  });

  it('throws for non-admin', () => {
    const auth = { sub: '1', phone: undefined, email: undefined, groups: ['Users'] };
    expect(() => requireAdmin(auth)).toThrow('Forbidden');
  });
});
