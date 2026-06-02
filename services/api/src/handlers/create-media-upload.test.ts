import { APIGatewayProxyEvent } from 'aws-lambda';
import { describe, expect, it, vi } from 'vitest';
import { createMediaUploadHandler } from './create-media-upload';
import { MAX_UPLOAD_BYTES } from '../media/validation';
import { normalizeUserPlan, UserPlan } from '../repositories/user-profiles';

const claims = {
  sub: 'user-1',
  email: 'user@example.com',
  'cognito:groups': 'Users',
};

const validBody = {
  source: 'IN_APP_CAMERA',
  contentType: 'image/jpeg',
  contentLength: 1024,
  gpsProof: {
    latitude: 10.771,
    longitude: 106.698,
    capturedAt: '2026-05-28T01:00:00.000Z',
    accuracyMeters: 12,
  },
};

const mockEvent = (body: unknown, eventClaims = claims): APIGatewayProxyEvent =>
  ({
    requestContext: { authorizer: { claims: eventClaims } },
    body: typeof body === 'string' ? body : JSON.stringify(body),
    headers: {},
    multiValueHeaders: {},
    httpMethod: 'POST',
    isBase64Encoded: false,
    path: '/media/uploads',
    pathParameters: null,
    queryStringParameters: null,
    multiValueQueryStringParameters: null,
    stageVariables: null,
    resource: '',
  }) as unknown as APIGatewayProxyEvent;

function setup(plan: UserPlan = 'FREE'): {
  handler: ReturnType<typeof createMediaUploadHandler>;
  createUploadPost: ReturnType<typeof vi.fn>;
  uploadInputs: unknown[];
} {
  const uploadInputs: unknown[] = [];
  const getPlan = vi.fn(async () => plan);
  const createUploadPost = vi.fn(async (input) => {
    uploadInputs.push(input);
    return {
      url: 'https://upload.example.com',
      fields: {
        key: input.key,
        'Content-Type': input.contentType,
      },
    };
  });
  const handler = createMediaUploadHandler({
    getPlan,
    createUploadPost,
    mediaIdFactory: () => 'media-1',
    env: {
      mediaBucket: 'fidee-dev-media',
      uploadExpirySeconds: 300,
    },
  });

  return { handler, createUploadPost, uploadInputs };
}

describe('create-media-upload handler', () => {
  it('blocks Free users from gallery uploads', async () => {
    const { handler, createUploadPost } = setup('FREE');

    const result = await handler(
      mockEvent({
        ...validBody,
        source: 'EXIF_GALLERY',
      }),
    );

    expect(result.statusCode).toBe(403);
    expect(JSON.parse(result.body).error).toContain('Pro');
    expect(createUploadPost).not.toHaveBeenCalled();
  });

  it('allows Free users to upload in-app camera photos', async () => {
    const { handler, createUploadPost, uploadInputs } = setup('FREE');

    const result = await handler(mockEvent(validBody));

    expect(result.statusCode).toBe(200);
    expect(createUploadPost).toHaveBeenCalledOnce();
    expect(uploadInputs[0]).toMatchObject({
      bucket: 'fidee-dev-media',
      key: 'uploads/media-1.jpg',
      contentType: 'image/jpeg',
      metadata: {
        'media-id': 'media-1',
        'owner-user-id': 'user-1',
        source: 'IN_APP_CAMERA',
        'gps-latitude': '10.771',
        'gps-longitude': '106.698',
        'gps-captured-at': '2026-05-28T01:00:00.000Z',
        'gps-accuracy-meters': '12',
      },
    });
    expect(JSON.parse(result.body)).toMatchObject({
      mediaId: 'media-1',
      upload: { url: 'https://upload.example.com' },
      expiresInSeconds: 300,
    });
  });

  it('allows Pro users to upload gallery photos', async () => {
    const { handler, createUploadPost } = setup('PRO');

    const result = await handler(
      mockEvent({
        ...validBody,
        source: 'EXIF_GALLERY',
      }),
    );

    expect(result.statusCode).toBe(200);
    expect(createUploadPost).toHaveBeenCalledOnce();
  });

  it('rejects invalid MIME types', async () => {
    const { handler } = setup('PRO');

    const result = await handler(
      mockEvent({
        ...validBody,
        contentType: 'image/gif',
      }),
    );

    expect(result.statusCode).toBe(400);
  });

  it('rejects oversized files', async () => {
    const { handler } = setup('PRO');

    const result = await handler(
      mockEvent({
        ...validBody,
        contentLength: MAX_UPLOAD_BYTES + 1,
      }),
    );

    expect(result.statusCode).toBe(400);
  });

  it('rejects missing GPS proof', async () => {
    const { handler } = setup('PRO');
    const body: Partial<typeof validBody> = { ...validBody };
    delete body.gpsProof;

    const result = await handler(mockEvent(body));

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error).toContain('gpsProof');
  });

  it('rejects invalid coordinates', async () => {
    const { handler } = setup('PRO');

    const result = await handler(
      mockEvent({
        ...validBody,
        gpsProof: { ...validBody.gpsProof, latitude: 91 },
      }),
    );

    expect(result.statusCode).toBe(400);
  });

  it('rejects invalid JSON', async () => {
    const { handler } = setup('PRO');

    const result = await handler(mockEvent('{not-json'));

    expect(result.statusCode).toBe(400);
  });

  it('treats missing or unknown user profile plan as Free', () => {
    expect(normalizeUserPlan(undefined)).toBe('FREE');
    expect(normalizeUserPlan('ENTERPRISE')).toBe('FREE');
    expect(normalizeUserPlan('PRO')).toBe('PRO');
  });
});
