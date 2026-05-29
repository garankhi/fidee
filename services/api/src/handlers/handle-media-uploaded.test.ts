import { SQSEvent } from 'aws-lambda';
import { describe, expect, it, vi } from 'vitest';
import { createHandleMediaUploadedHandler } from './handle-media-uploaded';
import { MAX_UPLOAD_BYTES } from '../media/validation';
import { MediaRecord, PutMediaResult } from '../repositories/media-records';

const eventBody = (key = 'uploads/media-1.jpg'): string =>
  JSON.stringify({
    source: 'aws.s3',
    'detail-type': 'Object Created',
    detail: {
      bucket: { name: 'fidee-dev-media' },
      object: { key, size: 1024 },
    },
  });

const sqsEvent = (body = eventBody()): SQSEvent =>
  ({
    Records: [
      {
        messageId: 'message-1',
        receiptHandle: 'receipt-1',
        body,
        attributes: {},
        messageAttributes: {},
        md5OfBody: '',
        eventSource: 'aws:sqs',
        eventSourceARN: 'arn:aws:sqs:ap-southeast-1:123456789012:queue',
        awsRegion: 'ap-southeast-1',
      },
    ],
  }) as SQSEvent;

const validMetadata = {
  'media-id': 'media-1',
  'owner-user-id': 'user-1',
  source: 'IN_APP_CAMERA',
  'gps-latitude': '10.771',
  'gps-longitude': '106.698',
  'gps-captured-at': '2026-05-28T01:00:00.000Z',
  'gps-accuracy-meters': '12',
};

function setup(options?: {
  contentType?: string;
  contentLength?: number;
  metadata?: Record<string, string>;
  putResult?: PutMediaResult;
}): {
  handler: ReturnType<typeof createHandleMediaUploadedHandler>;
  headObject: ReturnType<typeof vi.fn>;
  putMedia: ReturnType<typeof vi.fn>;
  putRecords: MediaRecord[];
} {
  const putRecords: MediaRecord[] = [];
  const headObject = vi.fn(async () => ({
    contentType: options?.contentType ?? 'image/jpeg',
    contentLength: options?.contentLength ?? 1024,
    metadata: options?.metadata ?? validMetadata,
  }));
  const putMedia = vi.fn(async (record: MediaRecord) => {
    putRecords.push(record);
    return options?.putResult ?? 'created';
  });
  const handler = createHandleMediaUploadedHandler({
    headObject,
    putMedia,
    now: () => '2026-05-28T02:00:00.000Z',
  });

  return { handler, headObject, putMedia, putRecords };
}

describe('handle-media-uploaded handler', () => {
  it('creates Media from a valid EventBridge-wrapped S3 upload event', async () => {
    const { handler, headObject, putMedia, putRecords } = setup();

    await handler(sqsEvent());

    expect(headObject).toHaveBeenCalledWith('fidee-dev-media', 'uploads/media-1.jpg');
    expect(putMedia).toHaveBeenCalledOnce();
    expect(putRecords[0]).toMatchObject({
      mediaId: 'media-1',
      ownerUserId: 'user-1',
      status: 'PENDING_MODERATION',
      s3Bucket: 'fidee-dev-media',
      s3Key: 'uploads/media-1.jpg',
      contentType: 'image/jpeg',
      contentLength: 1024,
      source: 'IN_APP_CAMERA',
      gpsProof: {
        latitude: 10.771,
        longitude: 106.698,
        capturedAt: '2026-05-28T01:00:00.000Z',
        accuracyMeters: 12,
      },
      createdAt: '2026-05-28T02:00:00.000Z',
      updatedAt: '2026-05-28T02:00:00.000Z',
    });
  });

  it('treats duplicate Media writes as idempotent success', async () => {
    const { handler, putMedia } = setup({ putResult: 'duplicate' });

    await expect(handler(sqsEvent())).resolves.toBeUndefined();

    expect(putMedia).toHaveBeenCalledOnce();
  });

  it('skips objects with missing metadata', async () => {
    const { handler, putMedia } = setup({
      metadata: {
        'media-id': 'media-1',
      },
    });

    await expect(handler(sqsEvent())).resolves.toBeUndefined();

    expect(putMedia).not.toHaveBeenCalled();
  });

  it('skips oversized uploaded objects', async () => {
    const { handler, putMedia } = setup({
      contentLength: MAX_UPLOAD_BYTES + 1,
    });

    await expect(handler(sqsEvent())).resolves.toBeUndefined();

    expect(putMedia).not.toHaveBeenCalled();
  });

  it('skips unsupported uploaded object content types', async () => {
    const { handler, putMedia } = setup({
      contentType: 'image/gif',
    });

    await expect(handler(sqsEvent())).resolves.toBeUndefined();

    expect(putMedia).not.toHaveBeenCalled();
  });

  it('skips object key mismatches', async () => {
    const { handler, putMedia } = setup();

    await expect(handler(sqsEvent(eventBody('uploads/other.jpg')))).resolves.toBeUndefined();

    expect(putMedia).not.toHaveBeenCalled();
  });

  it('decodes S3 keys from EventBridge body', async () => {
    const { handler, headObject } = setup();

    await handler(sqsEvent(eventBody('uploads%2Fmedia-1.jpg')));

    expect(headObject).toHaveBeenCalledWith('fidee-dev-media', 'uploads/media-1.jpg');
  });
});
