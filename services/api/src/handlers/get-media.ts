import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { getMediaRecord, MediaRecord } from '../repositories/media-records';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,OPTIONS',
};

interface GetMediaDeps {
  getMedia: (mediaId: string) => Promise<MediaRecord | null>;
  env: {
    mediaBaseUrl: string;
  };
}

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  };
}

function normalizeBaseUrl(value: string): string {
  return value.replace(/\/+$/, '');
}

function encodedS3Key(s3Key: string): string {
  return s3Key.split('/').map(encodeURIComponent).join('/');
}

function mediaLocation(mediaBaseUrl: string, s3Key: string): string {
  return `${normalizeBaseUrl(mediaBaseUrl)}/${encodedS3Key(s3Key)}`;
}

export function createGetMediaHandler(deps: GetMediaDeps) {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
      const mediaId = event.pathParameters?.mediaId?.trim();
      if (!mediaId) {
        return jsonResponse(400, { error: 'mediaId is required' });
      }

      const media = await deps.getMedia(mediaId);
      if (!media) {
        return jsonResponse(404, { error: 'Media not found' });
      }

      return {
        statusCode: 302,
        headers: {
          ...CORS_HEADERS,
          Location: mediaLocation(deps.env.mediaBaseUrl, media.s3Key),
          'Cache-Control': 'public, max-age=300',
        },
        body: '',
      };
    } catch (error) {
      console.error('Failed to resolve media URL', error);
      return jsonResponse(500, { error: 'Internal server error' });
    }
  };
}

function defaultDeps(): GetMediaDeps {
  const tableName = process.env.PLACES_TABLE;
  if (!tableName) {
    throw new Error('PLACES_TABLE is required');
  }

  const mediaDistributionDomainName = process.env.MEDIA_DISTRIBUTION_DOMAIN_NAME;
  if (!mediaDistributionDomainName) {
    throw new Error('MEDIA_DISTRIBUTION_DOMAIN_NAME is required');
  }

  return {
    getMedia: (mediaId) => getMediaRecord(tableName, mediaId),
    env: {
      mediaBaseUrl: `https://${mediaDistributionDomainName}`,
    },
  };
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> =>
  createGetMediaHandler(defaultDeps())(event);
