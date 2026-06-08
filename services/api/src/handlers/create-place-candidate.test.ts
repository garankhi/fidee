import { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { UserPlan } from '../repositories/user-profiles';

const { mockQuery, mockRandomUUID } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
  mockRandomUUID: vi.fn(),
}));

vi.mock('../db/client', () => ({
  query: mockQuery,
}));

vi.mock('crypto', async () => {
  const actual = await vi.importActual<typeof import('crypto')>('crypto');
  return {
    ...actual,
    randomUUID: mockRandomUUID,
  };
});

import { createPlaceCandidateHandler } from './create-place-candidate';

function mockEvent(body: Record<string, unknown>, sub = 'user-123'): APIGatewayProxyEvent {
  return {
    body: JSON.stringify(body),
    requestContext: {
      authorizer: {
        claims: { sub, 'cognito:groups': 'Users' },
      },
    },
  } as unknown as APIGatewayProxyEvent;
}

function mockDeps(overrides: Partial<Parameters<typeof createPlaceCandidateHandler>[0]> = {}) {
  return {
    getPlan: vi.fn<[string], Promise<UserPlan>>().mockResolvedValue('FREE'),
    verifyMedia: vi
      .fn<[string, string], Promise<{ lat: number; lng: number } | null>>()
      .mockResolvedValue({ lat: 10.77, lng: 106.7 }),
    candidateIdFactory: vi.fn().mockReturnValue('cand_test123'),
    env: {
      mediaBucket: 'test-media',
      userProfilesTable: 'test-profiles',
    },
    ...overrides,
  };
}

const validBody = {
  name: 'Quán Cà Phê Bình Minh',
  category: 'cafe',
  mediaId: 'photo-abc-123',
  coordinates: { lat: 10.7716, lng: 106.7042 },
};

function mockSuccessfulQueries() {
  mockQuery
    .mockResolvedValueOnce({ rows: [{ count: '0' }] })
    .mockResolvedValueOnce({ rows: [] })
    .mockResolvedValueOnce({ rows: [{ created_at: '2026-06-06T12:00:00.000Z' }] });
}

describe('createPlaceCandidateHandler', () => {
  beforeEach(() => {
    mockQuery.mockReset();
    mockRandomUUID.mockReset();
    mockRandomUUID.mockReturnValue('11111111-2222-4333-8444-555555555555');
  });

  it('creates candidate successfully (201)', async () => {
    mockSuccessfulQueries();
    const deps = mockDeps();
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent(validBody));

    expect(result.statusCode).toBe(201);
    const body = JSON.parse(result.body);
    expect(body.status).toBe('created');
    expect(body.data.candidate_id).toBe('11111111-2222-4333-8444-555555555555');
    expect(body.data.name).toBe('Quán Cà Phê Bình Minh');
    expect(body.data.status).toBe('PENDING_REVIEW');
    expect(body.data.visibility).toBe('FRIENDS');
    expect(deps.verifyMedia).toHaveBeenCalledWith('test-media', 'photo-abc-123');
    expect(mockQuery).toHaveBeenCalledTimes(3);
  });

  it('creates candidate without mediaId and skips media verification', async () => {
    mockSuccessfulQueries();
    const deps = mockDeps();
    const handler = createPlaceCandidateHandler(deps);
    const { mediaId: _mediaId, ...bodyWithoutMedia } = validBody;

    const result = await handler(mockEvent(bodyWithoutMedia));

    expect(result.statusCode).toBe(201);
    expect(deps.verifyMedia).not.toHaveBeenCalled();
    expect(mockQuery.mock.calls[2][1][6]).toBeNull();
  });

  it('returns 400 for missing name', async () => {
    const deps = mockDeps();
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent({ ...validBody, name: '' }));

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error.code).toBe('VALIDATION_ERROR');
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('returns 400 for invalid category', async () => {
    const deps = mockDeps();
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent({ ...validBody, category: 'invalid' }));

    expect(result.statusCode).toBe(400);
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('returns 400 for invalid media when mediaId is supplied', async () => {
    const deps = mockDeps({
      verifyMedia: vi.fn().mockResolvedValue(null),
    });
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent(validBody));

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error.code).toBe('INVALID_MEDIA');
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('returns 429 when quota exceeded (FREE)', async () => {
    mockQuery.mockResolvedValueOnce({ rows: [{ count: '5' }] });
    const deps = mockDeps();
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent(validBody));

    expect(result.statusCode).toBe(429);
    const body = JSON.parse(result.body);
    expect(body.error.code).toBe('QUOTA_EXCEEDED');
    expect(body.error.daily_limit).toBe(5);
  });

  it('allows PRO user higher quota', async () => {
    mockQuery
      .mockResolvedValueOnce({ rows: [{ count: '10' }] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ created_at: '2026-06-06T12:00:00.000Z' }] });
    const deps = mockDeps({
      getPlan: vi.fn().mockResolvedValue('PRO'),
    });
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent(validBody));

    expect(result.statusCode).toBe(201);
  });

  it('returns 409 for near-duplicate', async () => {
    mockQuery
      .mockResolvedValueOnce({ rows: [{ count: '0' }] })
      .mockResolvedValueOnce({
        rows: [
          {
            id: 'cand_existing',
            name: 'Quán Cà Phê Bình Minh',
            normalized_name: 'quan ca phe binh minh',
            distance_meters: '45',
          },
        ],
      });
    const deps = mockDeps();
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent(validBody));

    expect(result.statusCode).toBe(409);
    const body = JSON.parse(result.body);
    expect(body.status).toBe('conflict');
    expect(body.candidates).toHaveLength(1);
    expect(body.candidates[0].distanceMeters).toBe(45);
  });

  it('allows force create despite duplicates', async () => {
    mockQuery
      .mockResolvedValueOnce({ rows: [{ count: '0' }] })
      .mockResolvedValueOnce({ rows: [{ created_at: '2026-06-06T12:00:00.000Z' }] });
    const deps = mockDeps();
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent({ ...validBody, force: true }));

    expect(result.statusCode).toBe(201);
    expect(mockQuery).toHaveBeenCalledTimes(2);
  });

  it('returns 401 for missing auth', async () => {
    const deps = mockDeps();
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler({
      body: JSON.stringify(validBody),
      requestContext: { authorizer: { claims: {} } },
    } as unknown as APIGatewayProxyEvent);

    expect(result.statusCode).toBe(401);
  });
});
