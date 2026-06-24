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

  it('combines keyword, mapped vibe and multi-select filters', async () => {
    const result = await handler(
      event({
        lat: '10.77',
        lng: '106.70',
        q: 'Cà phê',
        vibe: 'hen_ho',
        category: 'cafe,restaurant',
        priceRange: '*-50000,100000-200000',
        disRange: '*-1000,3000-5000',
        sortBy: 'rating,price_asc',
      }),
    );

    expect(result.statusCode).toBe(200);
    const [sql, values] = mockQuery.mock.calls[0];
    expect(sql).toContain(
      "concat_ws(' ', p.category, p.name, p.normalized_name, p.description, p.metadata->>'vibe', p.metadata->>'features', p.metadata->>'vibes', p.metadata->>'services') ILIKE ANY($4::text[])",
    );
    expect(sql).toContain('p.category = ANY($5::text[])');
    expect(sql).toContain('COALESCE(p.price_min, p.price_max) <= $6');
    expect(sql).toContain('COALESCE(p.price_max, p.price_min) >= $7');
    expect(sql).toContain('ST_Distance(p.location, ST_MakePoint($1, $2)::geography)');
    expect(sql).toContain(
      'COALESCE(p.avg_rating, 0) DESC, p.price_min ASC NULLS LAST',
    );
    expect(values[0]).toBe(106.7);
    expect(values[1]).toBe(10.77);
    expect(values[2]).toBe('%ca phe%');
    expect(values[3]).toEqual(
      expect.arrayContaining(['%hẹn hò%', '%lãng mạn%', '%romantic%']),
    );
    expect(values.slice(4)).toEqual([
      ['cafe', 'restaurant'],
      50000,
      100000,
      200000,
      1000,
      3000,
      5000,
      21,
    ]);
  });

  it('supports legacy priceMax and radius parameters', async () => {
    const result = await handler(
      event({ lat: '10.77', lng: '106.70', priceMax: '70000', radius: '3000' }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery.mock.calls[0][1]).toEqual([106.7, 10.77, 70000, 3000, 21]);
  });

  it('rejects malformed ranges and unknown sort options', async () => {
    const invalidRange = await handler(
      event({ lat: '10.77', lng: '106.70', priceRange: '100000-50000' }),
    );
    const invalidSort = await handler(
      event({ lat: '10.77', lng: '106.70', sortBy: 'cheapest' }),
    );

    expect(invalidRange.statusCode).toBe(400);
    expect(invalidSort.statusCode).toBe(400);
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('matches cafe vibe by metadata or place category', async () => {
    const result = await handler(
      event({ lat: '10.77', lng: '106.70', vibe: 'cafe' }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery.mock.calls[0][0]).toContain('p.category = ANY($4::text[])');
    expect(mockQuery.mock.calls[0][1][2]).toEqual(
      expect.arrayContaining(['%cafe%', '%coffee%', '%cà phê%']),
    );
    expect(mockQuery.mock.calls[0][1]).toEqual([
      106.7,
      10.77,
      mockQuery.mock.calls[0][1][2],
      ['cafe'],
      21,
    ]);
  });

  it('matches green-space vibe from textual metadata', async () => {
    const result = await handler(
      event({ lat: '10.77', lng: '106.70', vibe: 'khong_gian_xanh' }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery.mock.calls[0][0]).toContain(
      "p.metadata->>'vibe', p.metadata->>'features'",
    );
    expect(mockQuery.mock.calls[0][1]).toEqual([
      106.7,
      10.77,
      expect.arrayContaining(['%không gian xanh%', '%sân vườn%', '%rooftop%']),
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
