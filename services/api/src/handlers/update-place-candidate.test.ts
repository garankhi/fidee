import { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockQuery } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
}));

vi.mock('../db/client', () => ({
  query: mockQuery,
}));

import { handler } from './update-place-candidate';

function event(
  candidateId: string,
  body: Record<string, unknown>,
  sub = 'user-123',
): APIGatewayProxyEvent {
  return {
    body: JSON.stringify(body),
    pathParameters: { id: candidateId },
    requestContext: {
      authorizer: {
        claims: { sub, 'cognito:groups': 'Users' },
      },
    },
  } as unknown as APIGatewayProxyEvent;
}

describe('updatePlaceCandidate handler', () => {
  beforeEach(() => {
    mockQuery.mockReset();
  });

  it('allows the creator to update candidate details and visibility', async () => {
    mockQuery
      .mockResolvedValueOnce({ rows: [{ id: 'candidate-1', created_by: 'user-123' }] })
      .mockResolvedValueOnce({
        rows: [
          {
            id: 'candidate-1',
            name: 'Cafe mới',
            address: '12 Nguyen Hue',
            open_time: '08:00',
            close_time: '22:00',
            price_min: 25000,
            price_max: 70000,
            phone_number: '0900000000',
            description: 'Yen tinh',
            visibility: 'PRIVATE',
            status: 'PENDING_REVIEW',
            updated_at: '2026-06-16T10:00:00.000Z',
          },
        ],
      });

    const result = await handler(
      event('candidate-1', {
        address: '12 Nguyen Hue',
        openTime: '08:00',
        closeTime: '22:00',
        priceMin: 25000,
        priceMax: 70000,
        phoneNumber: '0900000000',
        description: 'Yen tinh',
        visibility: 'PRIVATE',
      }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenNthCalledWith(2, expect.stringContaining('visibility = $8'), [
      '12 Nguyen Hue',
      '08:00',
      '22:00',
      25000,
      70000,
      '0900000000',
      'Yen tinh',
      'PRIVATE',
      'candidate-1',
    ]);
    expect(JSON.parse(result.body).data.visibility).toBe('PRIVATE');
  });

  it('rejects unsupported candidate visibility', async () => {
    const result = await handler(event('candidate-1', { visibility: 'PUBLIC' }));

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error.code).toBe('VALIDATION_ERROR');
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('rejects empty update payloads', async () => {
    const result = await handler(event('candidate-1', {}));

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error.code).toBe('VALIDATION_ERROR');
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('returns 403 when the requester is not the creator', async () => {
    mockQuery.mockResolvedValueOnce({ rows: [{ id: 'candidate-1', created_by: 'other-user' }] });

    const result = await handler(event('candidate-1', { address: '12 Nguyen Hue' }));

    expect(result.statusCode).toBe(403);
    expect(JSON.parse(result.body).error.code).toBe('FORBIDDEN');
  });

  it('returns 404 when candidate does not exist', async () => {
    mockQuery.mockResolvedValueOnce({ rows: [] });

    const result = await handler(event('missing-candidate', { address: '12 Nguyen Hue' }));

    expect(result.statusCode).toBe(404);
    expect(JSON.parse(result.body).error.code).toBe('NOT_FOUND');
  });
});
