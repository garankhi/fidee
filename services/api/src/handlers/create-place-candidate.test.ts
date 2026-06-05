import { describe, it, expect, vi } from 'vitest';
import { createPlaceCandidateHandler } from './create-place-candidate';
import { APIGatewayProxyEvent } from 'aws-lambda';
import { NearbyCandidate, PlaceCandidate } from '../repositories/place-candidates';
import { UserPlan } from '../repositories/user-profiles';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';

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
    putCandidate: vi.fn<[string, PlaceCandidate, DynamoDBDocumentClient?], Promise<'created' | 'duplicate'>>().mockResolvedValue('created'),
    countToday: vi.fn<[string, string, string, DynamoDBDocumentClient?], Promise<number>>().mockResolvedValue(0),
    findNearby: vi.fn<[string, number, number, number, string, DynamoDBDocumentClient?], Promise<NearbyCandidate[]>>().mockResolvedValue([]),
    verifyMedia: vi.fn<[string, string], Promise<{ lat: number; lng: number } | null>>().mockResolvedValue({ lat: 10.77, lng: 106.70 }),
    candidateIdFactory: vi.fn().mockReturnValue('cand_test123'),
    env: {
      placesTable: 'test-places',
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

describe('createPlaceCandidateHandler', () => {
  it('creates candidate successfully (201)', async () => {
    const deps = mockDeps();
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent(validBody));

    expect(result.statusCode).toBe(201);
    const body = JSON.parse(result.body);
    expect(body.status).toBe('created');
    expect(body.data.candidate_id).toBe('cand_test123');
    expect(body.data.name).toBe('Quán Cà Phê Bình Minh');
    expect(body.data.status).toBe('PENDING_REVIEW');
    expect(body.data.visibility).toBe('FRIENDS');
    expect(deps.putCandidate).toHaveBeenCalledOnce();
  });

  it('returns 400 for missing name', async () => {
    const deps = mockDeps();
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent({ ...validBody, name: '' }));

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error.code).toBe('VALIDATION_ERROR');
  });

  it('returns 400 for invalid category', async () => {
    const deps = mockDeps();
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent({ ...validBody, category: 'invalid' }));

    expect(result.statusCode).toBe(400);
  });

  it('returns 400 for invalid media', async () => {
    const deps = mockDeps({
      verifyMedia: vi.fn().mockResolvedValue(null),
    });
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent(validBody));

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error.code).toBe('INVALID_MEDIA');
  });

  it('returns 429 when quota exceeded (FREE)', async () => {
    const deps = mockDeps({
      countToday: vi.fn().mockResolvedValue(5), // FREE limit is 5
    });
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent(validBody));

    expect(result.statusCode).toBe(429);
    const body = JSON.parse(result.body);
    expect(body.error.code).toBe('QUOTA_EXCEEDED');
    expect(body.error.daily_limit).toBe(5);
  });

  it('allows PRO user higher quota', async () => {
    const deps = mockDeps({
      getPlan: vi.fn().mockResolvedValue('PRO'),
      countToday: vi.fn().mockResolvedValue(10), // Above FREE limit but under PRO limit
    });
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent(validBody));

    expect(result.statusCode).toBe(201);
  });

  it('returns 409 for near-duplicate', async () => {
    const deps = mockDeps({
      findNearby: vi.fn().mockResolvedValue([
        { candidateId: 'cand_existing', name: 'Quán Cà Phê Bình Minh', normalizedName: 'quan ca phe binh minh', distanceMeters: 45 },
      ]),
    });
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent(validBody));

    expect(result.statusCode).toBe(409);
    const body = JSON.parse(result.body);
    expect(body.status).toBe('conflict');
    expect(body.candidates).toHaveLength(1);
    expect(body.candidates[0].distanceMeters).toBe(45);
  });

  it('allows force create despite duplicates', async () => {
    const deps = mockDeps({
      findNearby: vi.fn().mockResolvedValue([
        { candidateId: 'cand_existing', name: 'Quán Cà Phê Bình Minh', normalizedName: 'quan ca phe binh minh', distanceMeters: 45 },
      ]),
    });
    const handler = createPlaceCandidateHandler(deps);
    const result = await handler(mockEvent({ ...validBody, force: true }));

    expect(result.statusCode).toBe(201);
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
