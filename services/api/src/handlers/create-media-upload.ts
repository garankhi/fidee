import { S3Client } from '@aws-sdk/client-s3';
import {
  createPresignedPost,
  PresignedPost,
  PresignedPostOptions,
} from '@aws-sdk/s3-presigned-post';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { randomUUID } from 'crypto';
import { extractAuth } from '../middleware/auth';
import {
  buildObjectKey,
  MAX_UPLOAD_BYTES,
  UPLOAD_EXPIRY_SECONDS,
  ValidatedUploadRequest,
  ValidationError,
  validateUploadRequest,
} from '../media/validation';
import { getUserPlan, UserPlan } from '../repositories/user-profiles';

interface CreateUploadPostInput {
  bucket: string;
  key: string;
  contentType: string;
  metadata: Record<string, string>;
  expiresInSeconds: number;
}

interface CreateMediaUploadDeps {
  getPlan: (userId: string) => Promise<UserPlan>;
  createUploadPost: (input: CreateUploadPostInput) => Promise<PresignedPost>;
  mediaIdFactory: () => string;
  env: {
    mediaBucket: string;
    uploadExpirySeconds: number;
  };
}

const s3Client = new S3Client({});

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  };
}

function parseJsonBody(event: APIGatewayProxyEvent): unknown {
  if (!event.body) {
    throw new ValidationError('Request body is required');
  }

  try {
    return JSON.parse(event.body) as unknown;
  } catch {
    throw new ValidationError('Request body must be valid JSON');
  }
}

function buildUploadMetadata(
  mediaId: string,
  ownerUserId: string,
  uploadRequest: ValidatedUploadRequest,
): Record<string, string> {
  const metadata: Record<string, string> = {
    'media-id': mediaId,
    'owner-user-id': ownerUserId,
    source: uploadRequest.source,
    'gps-latitude': String(uploadRequest.gpsProof.latitude),
    'gps-longitude': String(uploadRequest.gpsProof.longitude),
  };

  if (uploadRequest.gpsProof.capturedAt !== undefined) {
    metadata['gps-captured-at'] = uploadRequest.gpsProof.capturedAt;
  }
  if (uploadRequest.gpsProof.accuracyMeters !== undefined) {
    metadata['gps-accuracy-meters'] = String(uploadRequest.gpsProof.accuracyMeters);
  }

  return metadata;
}

function metadataPostFields(metadata: Record<string, string>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(metadata).map(([key, value]) => [`x-amz-meta-${key}`, value]),
  );
}

async function createS3UploadPost(input: CreateUploadPostInput): Promise<PresignedPost> {
  const metadataFields = metadataPostFields(input.metadata);
  const conditions: NonNullable<PresignedPostOptions['Conditions']> = [
    ['eq', '$key', input.key],
    ['eq', '$Content-Type', input.contentType],
    ['content-length-range', 1, MAX_UPLOAD_BYTES],
    ...Object.entries(metadataFields).map(
      ([field, value]) => ['eq', `$${field}`, value] as ['eq', string, string],
    ),
  ];

  return createPresignedPost(s3Client, {
    Bucket: input.bucket,
    Key: input.key,
    Fields: {
      'Content-Type': input.contentType,
      ...metadataFields,
    },
    Conditions: conditions,
    Expires: input.expiresInSeconds,
  });
}

function defaultDeps(): CreateMediaUploadDeps {
  const mediaBucket = process.env.MEDIA_BUCKET;
  if (!mediaBucket) {
    throw new Error('MEDIA_BUCKET is required');
  }

  const userProfilesTable = process.env.USER_PROFILES_TABLE;
  if (!userProfilesTable) {
    throw new Error('USER_PROFILES_TABLE is required');
  }

  const uploadExpirySeconds = Number(process.env.UPLOAD_EXPIRY_SECONDS ?? UPLOAD_EXPIRY_SECONDS);

  return {
    getPlan: (userId) => getUserPlan(userId, userProfilesTable),
    createUploadPost: createS3UploadPost,
    mediaIdFactory: randomUUID,
    env: {
      mediaBucket,
      uploadExpirySeconds: Number.isFinite(uploadExpirySeconds)
        ? uploadExpirySeconds
        : UPLOAD_EXPIRY_SECONDS,
    },
  };
}

export function createMediaUploadHandler(deps: CreateMediaUploadDeps) {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
      const auth = extractAuth(event);
      const uploadRequest = validateUploadRequest(parseJsonBody(event));
      const plan = await deps.getPlan(auth.sub);

      if (uploadRequest.source === 'EXIF_GALLERY' && plan !== 'PRO') {
        return jsonResponse(403, { error: 'Gallery uploads require Pro plan' });
      }

      const mediaId = deps.mediaIdFactory();
      const key = buildObjectKey(mediaId, uploadRequest.contentType);
      const metadata = buildUploadMetadata(mediaId, auth.sub, uploadRequest);
      const upload = await deps.createUploadPost({
        bucket: deps.env.mediaBucket,
        key,
        contentType: uploadRequest.contentType,
        metadata,
        expiresInSeconds: deps.env.uploadExpirySeconds,
      });

      return jsonResponse(200, {
        mediaId,
        upload: {
          url: upload.url,
          fields: upload.fields,
        },
        expiresInSeconds: deps.env.uploadExpirySeconds,
      });
    } catch (error) {
      if (error instanceof ValidationError) {
        return jsonResponse(400, { error: error.message });
      }

      if (error instanceof Error && error.message.startsWith('Forbidden')) {
        return jsonResponse(403, { error: error.message });
      }

      if (error instanceof Error && error.message.startsWith('Missing auth context')) {
        return jsonResponse(401, { error: error.message });
      }

      console.error('Failed to create media upload', error);
      return jsonResponse(500, { error: 'Internal server error' });
    }
  };
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> =>
  createMediaUploadHandler(defaultDeps())(event);
