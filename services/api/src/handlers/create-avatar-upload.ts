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
  MAX_UPLOAD_BYTES,
  UPLOAD_EXPIRY_SECONDS,
  ValidationError,
  SUPPORTED_CONTENT_TYPES,
  isSupportedContentType,
  extensionForContentType,
} from '../media/validation';

const s3Client = new S3Client({});

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
      'Access-Control-Allow-Methods': 'POST,OPTIONS',
    },
    body: JSON.stringify(body),
  };
}

function parseJsonBody(event: APIGatewayProxyEvent): Record<string, any> {
  if (!event.body) {
    throw new ValidationError('Request body is required');
  }

  try {
    return JSON.parse(event.body) as Record<string, any>;
  } catch {
    throw new ValidationError('Request body must be valid JSON');
  }
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    // 1. Authenticate user
    const auth = await extractAuth(event);

    // 2. Parse and validate request
    const body = parseJsonBody(event);
    const contentType = body.contentType;
    const contentLength = body.contentLength;

    if (!isSupportedContentType(contentType)) {
      throw new ValidationError('contentType must be image/jpeg, image/png, or image/webp');
    }

    if (
      typeof contentLength !== 'number' ||
      !Number.isInteger(contentLength) ||
      contentLength <= 0
    ) {
      throw new ValidationError('contentLength must be a positive integer');
    }
    if (contentLength > MAX_UPLOAD_BYTES) {
      throw new ValidationError('contentLength exceeds 5MB limit');
    }

    // 3. Generate mediaId and S3 object Key
    const mediaId = randomUUID();
    const extension = extensionForContentType(contentType);
    const key = `avatars/${mediaId}.${extension}`;

    const mediaBucket = process.env.MEDIA_BUCKET;
    if (!mediaBucket) {
      throw new Error('MEDIA_BUCKET is required');
    }

    const uploadExpirySeconds = Number(process.env.UPLOAD_EXPIRY_SECONDS ?? UPLOAD_EXPIRY_SECONDS);

    // 4. Generate metadata
    const metadata: Record<string, string> = {
      'media-id': mediaId,
      'owner-user-id': auth.sub,
      source: 'PROFILE_PICTURE',
    };

    const metadataFields = Object.fromEntries(
      Object.entries(metadata).map(([k, v]) => [`x-amz-meta-${k}`, v]),
    );

    const conditions: NonNullable<PresignedPostOptions['Conditions']> = [
      ['eq', '$key', key],
      ['eq', '$Content-Type', contentType],
      ['content-length-range', 1, MAX_UPLOAD_BYTES],
      ...Object.entries(metadataFields).map(
        ([field, value]) => ['eq', `$${field}`, value] as ['eq', string, string],
      ),
    ];

    const upload = await createPresignedPost(s3Client, {
      Bucket: mediaBucket,
      Key: key,
      Fields: {
        'Content-Type': contentType,
        ...metadataFields,
      },
      Conditions: conditions,
      Expires: uploadExpirySeconds,
    });

    const mediaDistributionDomainName = process.env.MEDIA_DISTRIBUTION_DOMAIN_NAME;

    return jsonResponse(200, {
      mediaId,
      upload: {
        url: upload.url,
        fields: upload.fields,
      },
      cdnUrl: mediaDistributionDomainName ? `https://${mediaDistributionDomainName}` : null,
      expiresInSeconds: uploadExpirySeconds,
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

    console.error('Failed to create avatar upload', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};
