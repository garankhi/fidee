import { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockQuery, mockExtractAuth } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
  mockExtractAuth: vi.fn(),
}));

vi.mock('../db/client', () => ({ query: mockQuery }));
vi.mock('../middleware/auth', () => ({ extractAuth: mockExtractAuth }));

import { handler } from './create-checkin';

const event = (body: unknown): APIGatewayProxyEvent =>
  ({
    headers: {},
    body: JSON.stringify(body),
    httpMethod: 'POST',
    isBase64Encoded: false,
    path: '/check-ins',
    pathParameters: null,
    queryStringParameters: null,
    multiValueQueryStringParameters: null,
    multiValueHeaders: {},
    requestContext: {},
    stageVariables: null,
    resource: '',
  }) as unknown as APIGatewayProxyEvent;

describe('create-checkin handler audience', () => {
  beforeEach(() => {
    mockQuery.mockReset();
    mockExtractAuth.mockReset();
    mockExtractAuth.mockResolvedValue({ sub: 'user-1' });
  });

  it('creates an all-friends check-in when audience.type is ALL_FRIENDS', async () => {
    mockQuery
      .mockResolvedValueOnce({
        rows: [{ id: 'checkin-1', created_at: '2026-06-12T01:00:00.000Z' }],
      })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    const result = await handler(
      event({
        place_id: 'place-1',
        media_id: 'media-1',
        gps_lat: 10.7738,
        gps_lng: 106.7035,
        visibility: 'FRIENDS',
        audience: { type: 'ALL_FRIENDS' },
      }),
    );

    expect(result.statusCode).toBe(201);
    expect(mockQuery).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining('INSERT INTO check_ins'),
      expect.arrayContaining([
        'user-1',
        'place-1',
        null,
        'media-1',
        10.7738,
        106.7035,
        null,
        null,
        null,
        'FRIENDS',
        'ALL_FRIENDS',
      ]),
    );
    expect(mockQuery).not.toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO check_in_recipients'),
      expect.anything(),
    );
  });

  it('stores media type when provided by video check-ins', async () => {
    mockQuery
      .mockResolvedValueOnce({
        rows: [{ id: 'checkin-video', created_at: '2026-06-12T01:00:00.000Z' }],
      })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    const result = await handler(
      event({
        place_id: 'place-1',
        media_id: 'media-video-1',
        media_type: 'VIDEO',
        gps_lat: 10.7738,
        gps_lng: 106.7035,
        audience: { type: 'ALL_FRIENDS' },
      }),
    );

    expect(result.statusCode).toBe(201);
    expect(mockQuery).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining('media_type'),
      expect.arrayContaining(['VIDEO']),
    );
  });

  it('creates direct recipient rows for multiple selected friends when audience.type is DIRECT', async () => {
    mockQuery
      .mockResolvedValueOnce({
        rows: [{ friend_id: 'friend-1' }, { friend_id: 'friend-2' }],
        rowCount: 2,
      })
      .mockResolvedValueOnce({
        rows: [{ id: 'checkin-2', created_at: '2026-06-12T01:01:00.000Z' }],
      })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    const result = await handler(
      event({
        place_id: 'place-1',
        media_id: 'media-1',
        gps_lat: 10.7738,
        gps_lng: 106.7035,
        audience: { type: 'DIRECT', friendIds: ['friend-1', 'friend-2'] },
      }),
    );

    expect(result.statusCode).toBe(201);
    expect(mockQuery).toHaveBeenNthCalledWith(1, expect.stringContaining('FROM friendships'), [
      'user-1',
      ['friend-1', 'friend-2'],
    ]);
    expect(mockQuery).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining('INSERT INTO check_ins'),
      expect.arrayContaining(['FRIENDS', 'DIRECT']),
    );
    expect(mockQuery).toHaveBeenNthCalledWith(
      3,
      expect.stringContaining('INSERT INTO check_in_recipients'),
      ['checkin-2', ['friend-1', 'friend-2']],
    );
  });

  it('rejects DIRECT audience with no friend ids', async () => {
    const result = await handler(
      event({
        place_id: 'place-1',
        media_id: 'media-1',
        gps_lat: 10.7738,
        gps_lng: 106.7035,
        audience: { type: 'DIRECT', friendIds: [] },
      }),
    );

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error).toContain('DIRECT audience requires at least one friend');
  });

  it('rejects DIRECT audience when any target user is not an accepted friend', async () => {
    mockQuery.mockResolvedValueOnce({ rows: [{ friend_id: 'friend-1' }], rowCount: 1 });

    const result = await handler(
      event({
        place_id: 'place-1',
        media_id: 'media-1',
        gps_lat: 10.7738,
        gps_lng: 106.7035,
        audience: { type: 'DIRECT', friendIds: ['friend-1', 'not-friend'] },
      }),
    );

    expect(result.statusCode).toBe(403);
    expect(JSON.parse(result.body).error).toContain('accepted friends');
  });
});
