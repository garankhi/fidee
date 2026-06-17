import { APIGatewayProxyEvent } from 'aws-lambda';
import { describe, expect, it, vi } from 'vitest';
import { createSearchHandler } from './search';

const claims = {
  sub: 'user-123',
  email: 'user@example.com',
  'cognito:groups': 'Users',
};

const mockEvent = (
  body: Record<string, unknown> | null,
  eventClaims: Record<string, unknown> = claims,
): APIGatewayProxyEvent =>
  ({
    body: body ? JSON.stringify(body) : null,
    headers: {},
    multiValueHeaders: {},
    httpMethod: 'POST',
    isBase64Encoded: false,
    path: '/search',
    pathParameters: null,
    queryStringParameters: null,
    multiValueQueryStringParameters: null,
    stageVariables: null,
    requestContext: { authorizer: { claims: eventClaims } },
    resource: '',
  }) as unknown as APIGatewayProxyEvent;

describe('search handler', () => {
  it('returns 400 when prompt is missing without counting quota', async () => {
    const incrementUsage = vi.fn();
    const searchPlaces = vi.fn();
    const handler = createSearchHandler({
      getPlan: vi.fn().mockResolvedValue('FREE'),
      incrementUsage,
      searchPlaces,
    });

    const result = await handler(mockEvent(null));

    expect(result.statusCode).toBe(400);
    expect(incrementUsage).not.toHaveBeenCalled();
  });

  it('returns 200 with quota metadata for valid prompt', async () => {
    const incrementUsage = vi.fn().mockResolvedValue({
      used: 1,
      limit: 5,
      allowed: true,
      usageDate: '2026-06-16',
    });
    const searchPlaces = vi.fn().mockResolvedValue({
      answer: 'Found a rooftop option.',
      search_method: 'keyword',
      results: [],
    });
    const handler = createSearchHandler({
      getPlan: vi.fn().mockResolvedValue('FREE'),
      incrementUsage,
      searchPlaces,
    });

    const result = await handler(mockEvent({ prompt: 'rooftop restaurant' }));

    expect(result.statusCode).toBe(200);
    const body = JSON.parse(result.body);
    expect(body.prompt).toBe('rooftop restaurant');
    expect(body.answer).toBe('Found a rooftop option.');
    expect(body.quota).toEqual({ limit: 5, used: 1, resetDate: '2026-06-16' });
    expect(searchPlaces).toHaveBeenCalledWith({
      prompt: 'rooftop restaurant',
      history: undefined,
      limit: 10,
    });
  });

  it('returns 429 when AI quota is exceeded', async () => {
    const searchPlaces = vi.fn();
    const handler = createSearchHandler({
      getPlan: vi.fn().mockResolvedValue('FREE'),
      incrementUsage: vi.fn().mockResolvedValue({
        used: 5,
        limit: 5,
        allowed: false,
        usageDate: '2026-06-16',
      }),
      searchPlaces,
    });

    const result = await handler(mockEvent({ prompt: 'late night cafe' }));

    expect(result.statusCode).toBe(429);
    expect(JSON.parse(result.body)).toMatchObject({
      error: 'AI_QUOTA_EXCEEDED',
      limit: 5,
      used: 5,
      resetDate: '2026-06-16',
    });
  });
});
