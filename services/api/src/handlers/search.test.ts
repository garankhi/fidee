import { describe, it, expect, vi, beforeEach } from 'vitest';
import { APIGatewayProxyEvent } from 'aws-lambda';

vi.mock('./search-core', async (importOriginal) => {
  const actual = await importOriginal<typeof import('./search-core')>();
  return {
    ...actual,
    listPublishedPlaces: vi.fn().mockResolvedValue([
      {
        id: 'demo-d1-001',
        name: 'Lantern Courtyard Pho',
        normalizedName: 'lantern-courtyard-pho',
        category: 'pho',
        lat: 10.7726,
        lng: 106.69885,
        address: '14 Le Loi, Ben Thanh, District 1, Ho Chi Minh City',
        sourceNote: 'Curated demo',
      },
      {
        id: 'demo-d1-006',
        name: 'Ben Thanh Brew Lab',
        normalizedName: 'ben-thanh-brew-lab',
        category: 'cafe',
        lat: 10.77291,
        lng: 106.69881,
        address: '23 Thu Khoa Huan, Ben Thanh, District 1, Ho Chi Minh City',
        sourceNote: 'Curated demo',
      },
    ]),
  };
});

import { handler } from './search';

const mockEvent = (body: Record<string, unknown> | null): APIGatewayProxyEvent =>
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
    requestContext: {} as APIGatewayProxyEvent['requestContext'],
    resource: '',
  }) as APIGatewayProxyEvent;

describe('search handler', () => {
  beforeEach(() => {
    process.env.PLACES_TABLE = 'mapvibe-dev-places';
  });

  it('returns 400 when body provides no searchable input', async () => {
    const result = await handler(mockEvent({}));
    expect(result.statusCode).toBe(400);
  });

  it('returns 400 for invalid JSON body', async () => {
    const result = await handler({
      ...mockEvent(null),
      body: '{bad json',
    } as APIGatewayProxyEvent);
    expect(result.statusCode).toBe(400);
  });

  it('returns 200 with results for a keyword prompt', async () => {
    const result = await handler(mockEvent({ prompt: 'pho' }));
    expect(result.statusCode).toBe(200);
    const body = JSON.parse(result.body);
    expect(Array.isArray(body.results)).toBe(true);
    expect(body.results.length).toBeGreaterThan(0);
    expect(body.results[0].category).toBe('pho');
  });

  it('returns 200 with results filtered by category', async () => {
    const result = await handler(mockEvent({ category: 'cafe' }));
    expect(result.statusCode).toBe(200);
    const body = JSON.parse(result.body);
    expect(body.results.every((r: { category: string }) => r.category === 'cafe')).toBe(true);
  });

  it('returns 200 with nearby results when coords provided', async () => {
    const result = await handler(mockEvent({ lat: 10.7726, lng: 106.69885, prompt: 'pho' }));
    expect(result.statusCode).toBe(200);
    const body = JSON.parse(result.body);
    expect(body.results[0]).toHaveProperty('distanceMeters');
  });

  it('returns 400 when only lat is provided without lng', async () => {
    const result = await handler(mockEvent({ lat: 10.7726, prompt: 'cafe' }));
    expect(result.statusCode).toBe(400);
  });
});
