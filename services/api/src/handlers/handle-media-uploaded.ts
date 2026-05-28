import { HeadObjectCommand, HeadObjectCommandOutput, S3Client } from '@aws-sdk/client-s3';
import { SQSEvent, SQSRecord } from 'aws-lambda';
import {
  buildObjectKey,
  MEDIA_STATUS_PENDING_MODERATION,
  SupportedContentType,
  UPLOAD_PREFIX,
  ValidatedUploadRequest,
  ValidationError,
  isSupportedContentType,
  validateUploadRequest,
} from '../media/validation';
import { MediaRecord, putMediaRecord, PutMediaResult } from '../repositories/media-records';

interface EventBridgeS3ObjectCreatedEvent {
  source?: string;
  'detail-type'?: string;
  detail?: {
    bucket?: { name?: string };
    object?: { key?: string; size?: number };
  };
}

interface HeadObjectResult {
  contentType: string | undefined;
  contentLength: number | undefined;
  metadata: Record<string, string>;
}

interface HandleMediaUploadedDeps {
  headObject: (bucket: string, key: string) => Promise<HeadObjectResult>;
  putMedia: (record: MediaRecord) => Promise<PutMediaResult>;
  now: () => string;
}

const s3Client = new S3Client({});

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function parseEventBridgeS3Event(record: SQSRecord): { bucket: string; key: string } {
  let event: EventBridgeS3ObjectCreatedEvent;
  try {
    event = JSON.parse(record.body) as EventBridgeS3ObjectCreatedEvent;
  } catch {
    throw new ValidationError('SQS message body must be a valid EventBridge event');
  }

  const bucket = event.detail?.bucket?.name;
  const rawKey = event.detail?.object?.key;

  if (event.source !== 'aws.s3' || event['detail-type'] !== 'Object Created') {
    throw new ValidationError('EventBridge event must be an S3 Object Created event');
  }
  if (!bucket || !rawKey) {
    throw new ValidationError('S3 object event must include bucket and key');
  }

  const key = decodeS3Key(rawKey);
  if (!key.startsWith(UPLOAD_PREFIX)) {
    throw new ValidationError('S3 object key must use uploads/ prefix');
  }

  return { bucket, key };
}

function decodeS3Key(key: string): string {
  try {
    return decodeURIComponent(key.replace(/\+/g, ' '));
  } catch {
    return key;
  }
}

function requireMetadata(metadata: Record<string, string>, key: string): string {
  const value = metadata[key];
  if (!value) {
    throw new ValidationError(`Object metadata is missing ${key}`);
  }
  return value;
}

function parseOptionalNumber(value: string | undefined): number | undefined {
  if (value === undefined) {
    return undefined;
  }

  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new ValidationError('Optional numeric metadata must be finite');
  }
  return parsed;
}

function uploadRequestFromObject(
  contentType: string | undefined,
  contentLength: number | undefined,
  metadata: Record<string, string>,
): { mediaId: string; ownerUserId: string; uploadRequest: ValidatedUploadRequest } {
  if (!isSupportedContentType(contentType)) {
    throw new ValidationError('Uploaded object has unsupported content type');
  }
  if (!Number.isInteger(contentLength)) {
    throw new ValidationError('Uploaded object must include content length');
  }

  const mediaId = requireMetadata(metadata, 'media-id');
  const ownerUserId = requireMetadata(metadata, 'owner-user-id');
  const source = requireMetadata(metadata, 'source');
  const latitude = Number(requireMetadata(metadata, 'gps-latitude'));
  const longitude = Number(requireMetadata(metadata, 'gps-longitude'));
  const capturedAt = metadata['gps-captured-at'];
  const accuracyMeters = parseOptionalNumber(metadata['gps-accuracy-meters']);

  const uploadRequest = validateUploadRequest({
    source,
    contentType,
    contentLength,
    gpsProof: {
      latitude,
      longitude,
      ...(capturedAt !== undefined ? { capturedAt } : {}),
      ...(accuracyMeters !== undefined ? { accuracyMeters } : {}),
    },
  });

  return { mediaId, ownerUserId, uploadRequest };
}

function mediaRecordFromObject(
  bucket: string,
  key: string,
  headObject: HeadObjectResult,
  now: string,
): MediaRecord {
  if (!isRecord(headObject.metadata)) {
    throw new ValidationError('Uploaded object metadata must be an object');
  }

  const { mediaId, ownerUserId, uploadRequest } = uploadRequestFromObject(
    headObject.contentType,
    headObject.contentLength,
    headObject.metadata,
  );

  const expectedKey = buildObjectKey(mediaId, uploadRequest.contentType as SupportedContentType);
  if (key !== expectedKey) {
    throw new ValidationError('Uploaded object key does not match media metadata');
  }

  return {
    mediaId,
    ownerUserId,
    status: MEDIA_STATUS_PENDING_MODERATION,
    s3Bucket: bucket,
    s3Key: key,
    contentType: uploadRequest.contentType,
    contentLength: uploadRequest.contentLength,
    source: uploadRequest.source,
    gpsProof: uploadRequest.gpsProof,
    createdAt: now,
    updatedAt: now,
  };
}

function headObjectResult(output: HeadObjectCommandOutput): HeadObjectResult {
  return {
    contentType: output.ContentType,
    contentLength: output.ContentLength,
    metadata: output.Metadata ?? {},
  };
}

function defaultDeps(): HandleMediaUploadedDeps {
  const mediaTable = process.env.PLACES_TABLE;
  if (!mediaTable) {
    throw new Error('PLACES_TABLE is required');
  }

  return {
    headObject: async (bucket, key): Promise<HeadObjectResult> => {
      const output = await s3Client.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
      return headObjectResult(output);
    },
    putMedia: (record) => putMediaRecord(mediaTable, record),
    now: () => new Date().toISOString(),
  };
}

async function handleRecord(record: SQSRecord, deps: HandleMediaUploadedDeps): Promise<void> {
  try {
    const { bucket, key } = parseEventBridgeS3Event(record);
    const object = await deps.headObject(bucket, key);
    const mediaRecord = mediaRecordFromObject(bucket, key, object, deps.now());
    const result = await deps.putMedia(mediaRecord);

    if (result === 'duplicate') {
      console.info('Media upload event already processed', { mediaId: mediaRecord.mediaId, key });
    }
  } catch (error) {
    if (error instanceof ValidationError) {
      console.warn('Skipping invalid media upload event', { error: error.message });
      return;
    }

    throw error;
  }
}

export function createHandleMediaUploadedHandler(deps: HandleMediaUploadedDeps) {
  return async (event: SQSEvent): Promise<void> => {
    for (const record of event.Records) {
      await handleRecord(record, deps);
    }
  };
}

export const handler = async (event: SQSEvent): Promise<void> =>
  createHandleMediaUploadedHandler(defaultDeps())(event);
