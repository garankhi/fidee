import { describe, it, expect, vi, beforeEach } from 'vitest';
import * as defineAuth from './define-auth-challenge';
import * as createAuth from './create-auth-challenge';
import * as verifyAuth from './verify-auth-challenge';
import {
  DefineAuthChallengeTriggerEvent,
  CreateAuthChallengeTriggerEvent,
  VerifyAuthChallengeResponseTriggerEvent,
} from 'aws-lambda';

// Use vi.hoisted to declare mock variables before vi.mock hoisting
const { mockSend } = vi.hoisted(() => ({
  mockSend: vi.fn().mockResolvedValue({ id: 'mock-email-id' }),
}));

vi.mock('resend', () => {
  return {
    Resend: vi.fn().mockImplementation(() => ({
      emails: {
        send: mockSend,
      },
    })),
  };
});

// Mock global fetch for verifyAuth testing
const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('define-auth-challenge', () => {
  it('issues CUSTOM_CHALLENGE on first call (session length 0)', async () => {
    const event = {
      request: { session: [] },
      response: {},
    } as unknown as DefineAuthChallengeTriggerEvent;

    const result = await defineAuth.handler(event);
    expect(result.response.challengeName).toBe('CUSTOM_CHALLENGE');
    expect(result.response.issueTokens).toBe(false);
    expect(result.response.failAuthentication).toBe(false);
  });

  it('issues tokens if last challenge was successful', async () => {
    const event = {
      request: {
        session: [{ challengeName: 'CUSTOM_CHALLENGE', challengeResult: true }],
      },
      response: {},
    } as unknown as DefineAuthChallengeTriggerEvent;

    const result = await defineAuth.handler(event);
    expect(result.response.issueTokens).toBe(true);
    expect(result.response.failAuthentication).toBe(false);
  });

  it('fails authentication immediately if Google flow fails', async () => {
    const event = {
      request: {
        clientMetadata: { provider: 'google' },
        session: [{ challengeName: 'CUSTOM_CHALLENGE', challengeResult: false, challengeMetadata: 'GOOGLE_TOKEN' }],
      },
      response: {},
    } as unknown as DefineAuthChallengeTriggerEvent;

    const result = await defineAuth.handler(event);
    expect(result.response.issueTokens).toBe(false);
    expect(result.response.failAuthentication).toBe(true);
  });

  it('allows retry on OTP failure if failed attempts < 5', async () => {
    const event = {
      request: {
        session: [{ challengeName: 'CUSTOM_CHALLENGE', challengeResult: false, challengeMetadata: 'OTP-123456789' }],
      },
      response: {},
    } as unknown as DefineAuthChallengeTriggerEvent;

    const result = await defineAuth.handler(event);
    expect(result.response.challengeName).toBe('CUSTOM_CHALLENGE');
    expect(result.response.issueTokens).toBe(false);
    expect(result.response.failAuthentication).toBe(false);
  });

  it('fails authentication if OTP failed attempts >= 5', async () => {
    const event = {
      request: {
        session: Array(5).fill({ challengeName: 'CUSTOM_CHALLENGE', challengeResult: false, challengeMetadata: 'OTP-123' }),
      },
      response: {},
    } as unknown as DefineAuthChallengeTriggerEvent;

    const result = await defineAuth.handler(event);
    expect(result.response.issueTokens).toBe(false);
    expect(result.response.failAuthentication).toBe(true);
  });
});

describe('create-auth-challenge', () => {
  beforeEach(() => {
    mockSend.mockClear();
    process.env.RESEND_SENDER_EMAIL = 'test@fidee.site';
  });

  it('bypasses email send for Google login and sets GOOGLE_TOKEN metadata', async () => {
    const event = {
      request: {
        clientMetadata: { provider: 'google' },
        userAttributes: { email: 'user@example.com' },
      },
      response: {},
    } as unknown as CreateAuthChallengeTriggerEvent;

    const result = await createAuth.handler(event);
    expect(mockSend).not.toHaveBeenCalled();
    expect(result.response.challengeMetadata).toBe('GOOGLE_TOKEN');
    expect(result.response.publicChallengeParameters?.provider).toBe('google');
    expect(result.response.privateChallengeParameters?.provider).toBe('google');
  });

  it('generates OTP and sends email for normal flow', async () => {
    const event = {
      request: {
        userAttributes: { email: 'user@example.com' },
      },
      response: {},
    } as unknown as CreateAuthChallengeTriggerEvent;

    const result = await createAuth.handler(event);
    expect(mockSend).toHaveBeenCalled();
    expect(result.response.challengeMetadata).toContain('OTP-');
    expect(result.response.privateChallengeParameters?.answer).toBeDefined();
    expect(result.response.publicChallengeParameters?.destination).toBe('us***@example.com');
  });
});

describe('verify-auth-challenge', () => {
  beforeEach(() => {
    mockFetch.mockClear();
    process.env.GOOGLE_CLIENT_ID = 'test-client-id';
  });

  it('verifies correct OTP answer', async () => {
    const event = {
      request: {
        privateChallengeParameters: { answer: '123456' },
        challengeAnswer: '123456',
      },
      response: {},
    } as unknown as VerifyAuthChallengeResponseTriggerEvent;

    const result = await verifyAuth.handler(event);
    expect(result.response.answerCorrect).toBe(true);
  });

  it('rejects incorrect OTP answer', async () => {
    const event = {
      request: {
        privateChallengeParameters: { answer: '123456' },
        challengeAnswer: '000000',
      },
      response: {},
    } as unknown as VerifyAuthChallengeResponseTriggerEvent;

    const result = await verifyAuth.handler(event);
    expect(result.response.answerCorrect).toBe(false);
  });

  it('verifies valid Google idToken', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        aud: 'test-client-id',
        email: 'user@example.com',
        email_verified: true,
      }),
    });

    const event = {
      request: {
        privateChallengeParameters: { provider: 'google' },
        challengeAnswer: 'valid-google-token',
        userAttributes: { email: 'user@example.com' },
      },
      response: {},
    } as unknown as VerifyAuthChallengeResponseTriggerEvent;

    const result = await verifyAuth.handler(event);
    expect(mockFetch).toHaveBeenCalledWith(
      'https://oauth2.googleapis.com/tokeninfo?id_token=valid-google-token'
    );
    expect(result.response.answerCorrect).toBe(true);
  });

  it('rejects Google idToken if audience is invalid', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        aud: 'wrong-client-id',
        email: 'user@example.com',
        email_verified: true,
      }),
    });

    const event = {
      request: {
        privateChallengeParameters: { provider: 'google' },
        challengeAnswer: 'some-token',
        userAttributes: { email: 'user@example.com' },
      },
      response: {},
    } as unknown as VerifyAuthChallengeResponseTriggerEvent;

    const result = await verifyAuth.handler(event);
    expect(result.response.answerCorrect).toBe(false);
  });

  it('rejects Google idToken if email does not match userAttributes', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        aud: 'test-client-id',
        email: 'attacker@example.com',
        email_verified: true,
      }),
    });

    const event = {
      request: {
        privateChallengeParameters: { provider: 'google' },
        challengeAnswer: 'some-token',
        userAttributes: { email: 'user@example.com' },
      },
      response: {},
    } as unknown as VerifyAuthChallengeResponseTriggerEvent;

    const result = await verifyAuth.handler(event);
    expect(result.response.answerCorrect).toBe(false);
  });

  it('rejects Google idToken if tokeninfo API returns HTTP error', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      status: 400,
    });

    const event = {
      request: {
        privateChallengeParameters: { provider: 'google' },
        challengeAnswer: 'invalid-token',
        userAttributes: { email: 'user@example.com' },
      },
      response: {},
    } as unknown as VerifyAuthChallengeResponseTriggerEvent;

    const result = await verifyAuth.handler(event);
    expect(result.response.answerCorrect).toBe(false);
  });
});
