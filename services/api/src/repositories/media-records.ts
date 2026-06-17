import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import {
  GpsProof,
  MediaSource,
  MediaType,
  SupportedContentType,
  mediaTypeForContentType,
} from '../media/validation';

export interface MediaRecord {
  mediaId: string;
  ownerUserId: string;
  status: 'PENDING_MODERATION';
  s3Bucket: string;
  s3Key: string;
  contentType: SupportedContentType;
  contentLength: number;
  source: MediaSource;
  mediaType: MediaType;
  durationMs?: number;
  gpsProof: GpsProof;
  createdAt: string;
  updatedAt: string;
}

export type PutMediaResult = 'created' | 'duplicate';

const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

export async function putMediaRecord(
  tableName: string,
  record: MediaRecord,
  client: DynamoDBDocumentClient = dynamoClient,
): Promise<PutMediaResult> {
  const item = {
    PK: `MEDIA#${record.mediaId}`,
    SK: 'METADATA',
    entityType: 'Media',
    mediaId: record.mediaId,
    ownerUserId: record.ownerUserId,
    status: record.status,
    s3Bucket: record.s3Bucket,
    s3Key: record.s3Key,
    contentType: record.contentType,
    contentLength: record.contentLength,
    source: record.source,
    mediaType: record.mediaType,
    ...(record.durationMs !== undefined ? { durationMs: record.durationMs } : {}),
    gpsProof: record.gpsProof,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
    GSI1PK: `USER#${record.ownerUserId}`,
    GSI1SK: `MEDIA#${record.createdAt}#${record.mediaId}`,
  };

  try {
    await client.send(
      new PutCommand({
        TableName: tableName,
        Item: item,
        ConditionExpression: 'attribute_not_exists(PK)',
      }),
    );
    return 'created';
  } catch (error) {
    if (error instanceof Error && error.name === 'ConditionalCheckFailedException') {
      return 'duplicate';
    }
    throw error;
  }
}

function mediaRecordFromItem(item: Record<string, unknown>): MediaRecord {
  const contentType = item.contentType as SupportedContentType;

  return {
    mediaId: item.mediaId as string,
    ownerUserId: item.ownerUserId as string,
    status: item.status as MediaRecord['status'],
    s3Bucket: item.s3Bucket as string,
    s3Key: item.s3Key as string,
    contentType,
    contentLength: item.contentLength as number,
    source: item.source as MediaSource,
    mediaType: (item.mediaType as MediaType | undefined) ?? mediaTypeForContentType(contentType),
    durationMs: item.durationMs as number | undefined,
    gpsProof: item.gpsProof as GpsProof,
    createdAt: item.createdAt as string,
    updatedAt: item.updatedAt as string,
  };
}

export async function getMediaRecord(
  tableName: string,
  mediaId: string,
  client: DynamoDBDocumentClient = dynamoClient,
): Promise<MediaRecord | null> {
  const result = await client.send(
    new GetCommand({
      TableName: tableName,
      Key: {
        PK: `MEDIA#${mediaId}`,
        SK: 'METADATA',
      },
    }),
  );

  if (!result.Item) {
    return null;
  }

  return mediaRecordFromItem(result.Item);
}
