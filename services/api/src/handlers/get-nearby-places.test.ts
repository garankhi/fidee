import { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockQuery } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
}));

vi.mock('../db/client', () => ({
  query: mockQuery,
}));

import { handler } from './get-nearby-places';

function nearbyEvent(radius = '1000', q?: string): APIGatewayProxyEvent {
  return {
    queryStringParameters: {
      lat: '10.7738',
      lng: '106.7035',
      radius,
      ...(q ? { q } : {}),
    },
    requestContext: {
      authorizer: {
        claims: { sub: 'user-123', 'cognito:groups': 'Users' },
      },
    },
  } as unknown as APIGatewayProxyEvent;
}

describe('getNearbyPlaces handler', () => {
  beforeEach(() => {
    mockQuery.mockReset();
    mockQuery.mockResolvedValue({ rows: [] });
  });

  it('honors a 1000 meter nearby radius for camera place picking', async () => {
    const result = await handler(nearbyEvent('1000'));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenNthCalledWith(1, expect.any(String), [
      106.7035,
      10.7738,
      1000,
      null,
    ]);
    expect(mockQuery).toHaveBeenNthCalledWith(2, expect.any(String), [
      106.7035,
      10.7738,
      1000,
      'user-123',
      null,
    ]);
    expect(JSON.parse(result.body).metadata.radius_meters).toBe(1000);
  });

  it('hides private friend candidates unless created by the viewer', async () => {
    const result = await handler(nearbyEvent('1000'));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining("(pc.visibility = 'FRIENDS' OR pc.created_by = $4)"),
      [106.7035, 10.7738, 1000, 'user-123', null],
    );
  });

  it('filters nearby places by name when q is provided', async () => {
    const result = await handler(nearbyEvent('1000', 'coffee'));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenNthCalledWith(1, expect.any(String), [
      106.7035,
      10.7738,
      1000,
      '%coffee%',
    ]);
    expect(mockQuery).toHaveBeenNthCalledWith(2, expect.any(String), [
      106.7035,
      10.7738,
      1000,
      'user-123',
      '%coffee%',
    ]);
    expect(JSON.parse(result.body).metadata.query).toBe('coffee');
  });
});
