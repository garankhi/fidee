import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';

import { randomUUID } from 'crypto';
import {
  encodeGeohash,
  geohashNeighbors,
  haversineDistance,
  levenshteinDistance,
} from '../utils/geo';

export const PLACE_CATEGORIES = [
  'cafe',
  'restaurant',
  'hotel',
  'tourist_attraction',
  'office',
  'shopping',
  'other',
] as const;

export type PlaceCategory = (typeof PLACE_CATEGORIES)[number];

export function isPlaceCategory(value: unknown): value is PlaceCategory {
  return typeof value === 'string' && PLACE_CATEGORIES.includes(value as PlaceCategory);
}

export type CandidateStatus = 'PENDING_REVIEW' | 'APPROVED' | 'REJECTED';
export type CandidateVisibility = 'FRIENDS' | 'PUBLIC';

export interface PlaceCandidate {
  candidateId: string;
  name: string;
  normalizedName: string;
  category: PlaceCategory;
  lat: number;
  lng: number;
  geohash: string;
  status: CandidateStatus;
  visibility: CandidateVisibility;
  createdBy: string;
  mediaId: string;
  createdAt: string;
  updatedAt: string;
}

export interface NearbyCandidate {
  candidateId: string;
  name: string;
  normalizedName: string;
  distanceMeters: number;
}

const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

export function buildCandidateId(): string {
  return `cand_${randomUUID().replace(/-/g, '').slice(0, 12)}`;
}

/** Create a new place candidate in DynamoDB. */
export async function putCandidate(
  tableName: string,
  candidate: PlaceCandidate,
  client: DynamoDBDocumentClient = dynamoClient,
): Promise<'created' | 'duplicate'> {
  const now = candidate.createdAt;
  const dateKey = now.slice(0, 10); // YYYY-MM-DD

  const item = {
    PK: `CANDIDATE#${candidate.candidateId}`,
    SK: 'META',
    entityType: 'PlaceCandidate',
    ...candidate,
    // GSI1: user's candidates (for quota)
    GSI1PK: `USER_CANDIDATES#${candidate.createdBy}`,
    GSI1SK: `${dateKey}#${candidate.candidateId}`,
    // GSI2: geo-based dedup
    GSI2PK: `GEO#${candidate.geohash}`,
    GSI2SK: `CANDIDATE#${candidate.normalizedName}#${candidate.candidateId}`,
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

/** Count how many candidates a user created today (for quota enforcement). */
export async function countUserCandidatesToday(
  tableName: string,
  userId: string,
  dateStr: string,
  client: DynamoDBDocumentClient = dynamoClient,
): Promise<number> {
  const result = await client.send(
    new QueryCommand({
      TableName: tableName,
      IndexName: 'GSI1',
      KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :datePrefix)',
      ExpressionAttributeValues: {
        ':pk': `USER_CANDIDATES#${userId}`,
        ':datePrefix': `${dateStr}#`,
      },
      Select: 'COUNT',
    }),
  );
  return result.Count ?? 0;
}

/** Find nearby candidates within a geohash cell for dedup checking. */
export async function findNearbyCandidates(
  tableName: string,
  lat: number,
  lng: number,
  radiusMeters: number,
  normalizedName: string,
  client: DynamoDBDocumentClient = dynamoClient,
): Promise<NearbyCandidate[]> {
  const geohash = encodeGeohash(lat, lng, 4);
  const neighbors = geohashNeighbors(geohash);
  const candidates: NearbyCandidate[] = [];

  for (const gh of neighbors) {
    const result = await client.send(
      new QueryCommand({
        TableName: tableName,
        IndexName: 'GSI2',
        KeyConditionExpression: 'GSI2PK = :pk AND begins_with(GSI2SK, :prefix)',
        ExpressionAttributeValues: {
          ':pk': `GEO#${gh}`,
          ':prefix': 'CANDIDATE#',
        },
      }),
    );

    for (const item of result.Items ?? []) {
      const dist = haversineDistance(lat, lng, item.lat as number, item.lng as number);
      if (dist > radiusMeters) continue;

      const nameDist = levenshteinDistance(normalizedName, item.normalizedName as string);
      const isExactMatch = normalizedName === item.normalizedName;
      const isFuzzyMatch = nameDist <= 3;

      if (isExactMatch || isFuzzyMatch) {
        candidates.push({
          candidateId: item.candidateId as string,
          name: item.name as string,
          normalizedName: item.normalizedName as string,
          distanceMeters: Math.round(dist),
        });
      }
    }
  }

  return candidates;
}

/** Quota limits per user tier. */
export const QUOTA_LIMITS = {
  FREE: 5,
  PRO: 15,
} as const;
