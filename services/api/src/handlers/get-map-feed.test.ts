import { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockQuery, mockExtractAuth } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
  mockExtractAuth: vi.fn(),
}));

vi.mock('../db/client', () => ({ query: mockQuery }));
vi.mock('../middleware/auth', () => ({ extractAuth: mockExtractAuth }));

import { handler } from './get-map-feed';

const event = (queryStringParameters?: Record<string, string>): APIGatewayProxyEvent =>
  ({
    headers: {},
    body: null,
    httpMethod: 'GET',
    isBase64Encoded: false,
    path: '/map/feed',
    pathParameters: null,
    queryStringParameters: queryStringParameters ?? {
      lat: '10.7738',
      lng: '106.7035',
      radius: '5000',
    },
    multiValueQueryStringParameters: null,
    multiValueHeaders: {},
    requestContext: {},
    stageVariables: null,
    resource: '',
  }) as unknown as APIGatewayProxyEvent;

describe('get-map-feed handler', () => {
  beforeEach(() => {
    mockQuery.mockReset();
    mockExtractAuth.mockReset();
    mockExtractAuth.mockResolvedValue({ sub: 'user-1' });
  });

  it('selects place metadata needed by upgraded map markers and bottom popup', async () => {
    mockQuery.mockResolvedValueOnce({ rows: [] });

    const result = await handler(event());

    expect(result.statusCode).toBe(200);
    const sql = mockQuery.mock.calls[0][0] as string;
    expect(sql).toContain('COALESCE(p.address, pc.address) as address');
    expect(sql).toContain('CASE WHEN ci.candidate_id IS NOT NULL THEN true ELSE false END as "isCandidate"');
    expect(sql).toContain('COALESCE(pc.visibility, ps.visibility, ci.visibility) as visibility');
    expect(sql).toContain('COALESCE(pc.created_by, p.created_by) as "createdBy"');
    expect(sql).toContain('creator.display_name as "createdByName"');
    expect(sql).toContain('pc.status as "candidateStatus"');
    expect(sql).toContain('COUNT(*) OVER (PARTITION BY COALESCE(p.id, pc.id))::integer as "placeCheckinCount"');
    expect(sql).toContain('recent_activity."recentAvatars"');
  });

  it('includes candidate places without check-ins in the marker feed query', async () => {
    mockQuery.mockResolvedValueOnce({ rows: [] });

    const result = await handler(event());

    expect(result.statusCode).toBe(200);
    const sql = mockQuery.mock.calls[0][0] as string;
    expect(sql).toContain('UNION ALL');
    expect(sql).toContain('FROM place_candidates pc');
    expect(sql).toContain("NOT EXISTS (");
    expect(sql).toContain("'candidate-' || pc.id");
    expect(sql).toContain("pc.visibility = 'FRIENDS' OR pc.created_by = $1");
    expect(sql).toContain('ST_DWithin(pc.location, ST_MakePoint($2, $3)::geography, $4)');
  });

  it('returns upgraded rows without changing the response envelope', async () => {
    mockQuery.mockResolvedValueOnce({
      rows: [
        {
          id: 'checkin-1',
          caption: 'Nice coffee',
          createdAt: '2026-06-22T09:00:00.000Z',
          mediaId: 'media-1',
          mediaType: 'IMAGE',
          userId: 'friend-1',
          userName: 'An',
          userAvatar: 'https://example.com/an.png',
          placeId: 'candidate-1',
          placeName: 'Cafe mới',
          category: 'cafe',
          address: '12 Nguyen Hue',
          lat: 10.7738,
          lng: 106.7035,
          visibility: 'FRIENDS',
          isCandidate: true,
          createdBy: 'user-1',
          createdByName: 'Minh',
          candidateStatus: 'PENDING_REVIEW',
          placeCheckinCount: 3,
          recentAvatars: ['https://example.com/an.png'],
          recentUserNames: ['An'],
        },
      ],
    });

    const result = await handler(event());

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body)).toEqual({
      data: [
        expect.objectContaining({
          placeId: 'candidate-1',
          address: '12 Nguyen Hue',
          isCandidate: true,
          visibility: 'FRIENDS',
          createdByName: 'Minh',
          placeCheckinCount: 3,
          recentUserNames: ['An'],
        }),
      ],
    });
  });
});
