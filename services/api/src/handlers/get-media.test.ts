import { APIGatewayProxyEvent } from 'aws-lambda';
import { describe, expect, it, vi } from 'vitest';
import { createGetMediaHandler } from './get-media';
import { MediaRecord } from '../repositories/media-records';

const event = (mediaId: string | null): APIGatewayProxyEvent =>
  ({
    headers: {},
    body: null,
    httpMethod: 'GET',
    isBase64Encoded: false,
    path: mediaId === null ? '/media' : `/media/${mediaId}`,
    pathParameters: mediaId === null ? null : { mediaId },
    queryStringParameters: null,
    multiValueQueryStringParameters: null,
    multiValueHeaders: {},
    requestContext: {},
    stageVariables: null,
    resource: '',
  }) as unknown as APIGatewayProxyEvent;

const record = (overrides: Partial<MediaRecord> = {}): MediaRecord => ({
  mediaId: 'media-1',
  ownerUserId: 'user-1',
  status: 'PENDING_MODERATION',
  s3Bucket: 'fidee-dev-media',
  s3Key: 'uploads/media-1.jpg',
  contentType: 'image/jpeg',
  contentLength: 1024,
  source: 'IN_APP_CAMERA',
  mediaType: 'IMAGE',
  gpsProof: { latitude: 10.7738, longitude: 106.7035 },
  createdAt: '2026-06-12T01:00:00.000Z',
  updatedAt: '2026-06-12T01:00:00.000Z',
  ...overrides,
});

describe('get-media handler', () => {
  it('redirects a media id to its CloudFront object URL', async () => {
    const getMedia = vi.fn().mockResolvedValue(record());
    const handler = createGetMediaHandler({
      getMedia,
      env: { mediaBaseUrl: 'https://cdn.example.cloudfront.net' },
    });

    const result = await handler(event('media-1'));

    expect(result.statusCode).toBe(302);
    expect(result.headers?.Location).toBe('https://cdn.example.cloudfront.net/uploads/media-1.jpg');
    expect(result.headers?.['Cache-Control']).toBe('public, max-age=300');
    expect(getMedia).toHaveBeenCalledWith('media-1');
  });

  it('encodes each S3 key segment without escaping path separators', async () => {
    const handler = createGetMediaHandler({
      getMedia: vi.fn().mockResolvedValue(record({ s3Key: 'uploads/folder name/media 1.jpg' })),
      env: { mediaBaseUrl: 'https://cdn.example.cloudfront.net/' },
    });

    const result = await handler(event('media-1'));

    expect(result.statusCode).toBe(302);
    expect(result.headers?.Location).toBe(
      'https://cdn.example.cloudfront.net/uploads/folder%20name/media%201.jpg',
    );
  });

  it('returns 400 when path mediaId is missing', async () => {
    const handler = createGetMediaHandler({
      getMedia: vi.fn(),
      env: { mediaBaseUrl: 'https://cdn.example.cloudfront.net' },
    });

    const result = await handler(event(null));

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error).toBe('mediaId is required');
  });

  it('returns 404 when media metadata is missing', async () => {
    const handler = createGetMediaHandler({
      getMedia: vi.fn().mockResolvedValue(null),
      env: { mediaBaseUrl: 'https://cdn.example.cloudfront.net' },
    });

    const result = await handler(event('missing-media'));

    expect(result.statusCode).toBe(404);
    expect(JSON.parse(result.body).error).toBe('Media not found');
  });
});
