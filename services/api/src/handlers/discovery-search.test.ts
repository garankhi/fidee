import { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockQuery } = vi.hoisted(() => ({ mockQuery: vi.fn() }));

vi.mock('../db/client', () => ({ query: mockQuery }));

import { handler } from './discovery-search';

function event(queryStringParameters: Record<string, string>): APIGatewayProxyEvent {
  return {
    queryStringParameters,
    requestContext: {
      authorizer: {
        claims: { sub: 'user-1', 'cognito:groups': 'Users' },
      },
    },
  } as unknown as APIGatewayProxyEvent;
}

describe('discovery search handler', () => {
  beforeEach(() => {
    mockQuery.mockReset();
    mockQuery.mockResolvedValue({ rows: [] });
  });

  it('requires valid coordinates', async () => {
    const result = await handler(event({ lat: 'invalid', lng: '106.70' }));

    expect(result.statusCode).toBe(400);
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('combines keyword, mapped vibe, category and price filters', async () => {
    const result = await handler(
      event({
        lat: '10.77',
        lng: '106.70',
        q: 'Cà phê',
        vibe: 'hen_ho',
        category: 'cafe',
        priceMax: '70000',
        radius: '3000',
        sortBy: 'rating',
      }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(
      expect.stringContaining("COALESCE(p.metadata->'vibes', '[]'::jsonb) ?| $5::text[]"),
      [106.7, 10.77, 3000, '%ca phe%', ['Dating'], 'cafe', 70000, 21],
    );
    expect(mockQuery.mock.calls[0][0]).toContain('COALESCE(p.avg_rating, 0) DESC');
  });

  it('matches cafe vibe by metadata or place category', async () => {
    const result = await handler(
      event({ lat: '10.77', lng: '106.70', vibe: 'cafe' }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery.mock.calls[0][0]).toContain('p.category = ANY($4::text[])');
    expect(mockQuery.mock.calls[0][1]).toEqual([
      106.7,
      10.77,
      ['Cafe'],
      ['cafe'],
      21,
    ]);
  });

  it('matches green-space vibe from vibes or services metadata', async () => {
    const result = await handler(
      event({ lat: '10.77', lng: '106.70', vibe: 'khong_gian_xanh' }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery.mock.calls[0][0]).toContain(
      "COALESCE(p.metadata->'services', '[]'::jsonb) ?| $4::text[]",
    );
    expect(mockQuery.mock.calls[0][1]).toEqual([
      106.7,
      10.77,
      ['Outdoor'],
      ['Outdoor'],
      21,
    ]);
  });

  it('searches keywords globally when radius is not selected', async () => {
    const result = await handler(
      event({ lat: '21.03', lng: '105.85', q: 'the', sortBy: 'distance' }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery.mock.calls[0][0]).not.toContain('ST_DWithin');
    expect(mockQuery.mock.calls[0][1]).toEqual([105.85, 21.03, '%the%', 21]);
  });

  it('returns a cursor and clamps limit to 50', async () => {
    mockQuery.mockResolvedValue({
      rows: Array.from({ length: 51 }, (_, index) => ({
        placeId: `place-${index}`,
        createdAt: new Date(Date.UTC(2026, 5, 19, 0, 0, index)).toISOString(),
      })),
    });

    const result = await handler(
      event({ lat: '10.77', lng: '106.70', limit: '200', sortBy: 'popular' }),
    );
    const body = JSON.parse(result.body);

    expect(result.statusCode).toBe(200);
    expect(body.data).toHaveLength(50);
    expect(body.pagination.hasMore).toBe(true);
    expect(body.pagination.nextCursor).toBe('2026-06-19T00:00:49.000Z');
    expect(mockQuery.mock.calls[0][1]).toEqual([106.7, 10.77, 51]);
  });
});
