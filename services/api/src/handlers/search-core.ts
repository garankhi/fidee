import { AttributeValue, DynamoDBClient, QueryCommand } from '@aws-sdk/client-dynamodb';

export interface PublishedPlace {
  id: string;
  name: string;
  normalizedName: string;
  category: string;
  lat: number;
  lng: number;
  address: string;
  sourceNote: string;
}

export interface SearchRequest {
  prompt?: string;
  lat?: number;
  lng?: number;
  radiusMeters: number;
  limit: number;
  category?: string;
}

export interface SearchResult extends PublishedPlace {
  distanceMeters: number | null;
  score: number;
  matchedTerms: string[];
}

const DEFAULT_RADIUS_METERS = 900;
const MAX_RADIUS_METERS = 5000;
const DEFAULT_LIMIT = 12;
const MAX_LIMIT = 25;
const GSI1_INDEX_NAME = 'GSI1';
const PUBLISHED_STATUS = 'PUBLISHED';
const PLACE_ENTITY = 'PLACE';

const CATEGORY_KEYWORDS: Record<string, string[]> = {
  bakery: ['bakery', 'bread', 'pastry'],
  banh_mi: ['banh mi', 'banh_mi', 'sandwich'],
  brunch: ['brunch', 'breakfast'],
  cafe: ['cafe', 'coffee', 'roastery'],
  dessert: ['dessert', 'gelato', 'sweet'],
  grill: ['grill', 'bbq', 'barbecue'],
  hotpot: ['hotpot', 'lau'],
  juice_bar: ['juice', 'smoothie'],
  noodle_shop: ['noodle', 'bun', 'dumpling'],
  pho: ['pho'],
  rooftop_bar: ['rooftop', 'bar', 'cocktail'],
  seafood: ['seafood', 'oyster'],
  tea_house: ['tea', 'tea house', 'teahouse'],
  vegetarian: ['vegetarian', 'vegan'],
  vietnamese: ['vietnamese', 'com', 'bun cha'],
};

const dynamoClient = new DynamoDBClient({});

export class SearchRequestError extends Error {}

const normalizeText = (value: string): string =>
  value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const tokenize = (value: string): string[] =>
  normalizeText(value)
    .split(' ')
    .map((token) => token.trim())
    .filter((token) => token.length > 0);

const parseOptionalNumber = (value: unknown, fieldName: string): number | undefined => {
  if (value === undefined || value === null || value === '') {
    return undefined;
  }

  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(parsed)) {
    throw new SearchRequestError(`Invalid numeric field: ${fieldName}`);
  }

  return parsed;
};

const parseOptionalString = (value: unknown): string | undefined => {
  if (typeof value !== 'string') {
    return undefined;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
};

const clampInteger = (value: number, min: number, max: number): number =>
  Math.max(min, Math.min(max, Math.round(value)));

export const parseSearchRequest = (body: unknown): SearchRequest => {
  const payload = body && typeof body === 'object' ? (body as Record<string, unknown>) : {};
  const prompt = parseOptionalString(payload.prompt);
  const category = parseOptionalString(payload.category);
  const lat = parseOptionalNumber(payload.lat, 'lat');
  const lng = parseOptionalNumber(payload.lng, 'lng');
  const radiusMeters = clampInteger(
    parseOptionalNumber(payload.radiusMeters, 'radiusMeters') ?? DEFAULT_RADIUS_METERS,
    100,
    MAX_RADIUS_METERS,
  );
  const limit = clampInteger(
    parseOptionalNumber(payload.limit, 'limit') ?? DEFAULT_LIMIT,
    1,
    MAX_LIMIT,
  );

  if (!prompt && lat === undefined && lng === undefined && !category) {
    throw new SearchRequestError('Provide a prompt, coordinates, or category to search places.');
  }

  if ((lat === undefined) !== (lng === undefined)) {
    throw new SearchRequestError('Both lat and lng are required for nearby search.');
  }

  if (lat !== undefined && (lat < -90 || lat > 90)) {
    throw new SearchRequestError('lat must be between -90 and 90.');
  }

  if (lng !== undefined && (lng < -180 || lng > 180)) {
    throw new SearchRequestError('lng must be between -180 and 180.');
  }

  return { prompt, lat, lng, radiusMeters, limit, category };
};

export const calculateDistanceMeters = (
  fromLat: number,
  fromLng: number,
  toLat: number,
  toLng: number,
): number => {
  const earthRadiusMeters = 6371000;
  const toRadians = (value: number) => (value * Math.PI) / 180;
  const dLat = toRadians(toLat - fromLat);
  const dLng = toRadians(toLng - fromLng);
  const lat1 = toRadians(fromLat);
  const lat2 = toRadians(toLat);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLng / 2) * Math.sin(dLng / 2) * Math.cos(lat1) * Math.cos(lat2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return Math.round(earthRadiusMeters * c);
};

const categoryMatchesPrompt = (category: string, normalizedPrompt: string): boolean => {
  const keywords = CATEGORY_KEYWORDS[category] ?? [];
  return keywords.some((keyword) => normalizedPrompt.includes(normalizeText(keyword)));
};

const deriveMatchedTerms = (place: PublishedPlace, prompt: string | undefined): string[] => {
  if (!prompt) {
    return [];
  }

  const normalizedPrompt = normalizeText(prompt);
  const normalizedName = normalizeText(place.name);
  const normalizedAddress = normalizeText(place.address);
  const matchedTerms = new Set<string>();

  tokenize(prompt).forEach((token) => {
    if (normalizedName.includes(token) || normalizedAddress.includes(token)) {
      matchedTerms.add(token);
    }
  });

  if (categoryMatchesPrompt(place.category, normalizedPrompt)) {
    matchedTerms.add(place.category);
  }

  return [...matchedTerms];
};

const scorePlace = (place: PublishedPlace, request: SearchRequest): SearchResult | null => {
  const explicitCategory = request.category
    ? normalizeText(request.category).replace(/\s+/g, '_')
    : undefined;
  if (explicitCategory && place.category !== explicitCategory) {
    return null;
  }

  const normalizedPrompt = request.prompt ? normalizeText(request.prompt) : undefined;
  const normalizedName = normalizeText(place.name);
  const normalizedAddress = normalizeText(place.address);
  const normalizedCategory = normalizeText(place.category.replace(/_/g, ' '));
  const promptTokens = request.prompt ? tokenize(request.prompt) : [];

  let distanceMeters: number | null = null;
  if (request.lat !== undefined && request.lng !== undefined) {
    distanceMeters = calculateDistanceMeters(request.lat, request.lng, place.lat, place.lng);
    if (distanceMeters > request.radiusMeters) {
      return null;
    }
  }

  let score = 0;
  const matchedTerms = new Set<string>();

  if (normalizedPrompt) {
    if (normalizedName.includes(normalizedPrompt)) {
      score += 10;
      matchedTerms.add(request.prompt as string);
    }

    if (normalizedAddress.includes(normalizedPrompt)) {
      score += 4;
      matchedTerms.add(request.prompt as string);
    }

    if (normalizedPrompt.includes(normalizedCategory) || categoryMatchesPrompt(place.category, normalizedPrompt)) {
      score += 8;
      matchedTerms.add(place.category);
    }

    promptTokens.forEach((token) => {
      if (normalizedName.includes(token)) {
        score += 3;
        matchedTerms.add(token);
      } else if (normalizedAddress.includes(token)) {
        score += 1;
        matchedTerms.add(token);
      }
    });

    if (score === 0 && request.lat === undefined && !explicitCategory) {
      return null;
    }
  }

  if (explicitCategory && place.category === explicitCategory) {
    score += 4;
    matchedTerms.add(place.category);
  }

  if (distanceMeters !== null) {
    score += Math.max(0, 6 - distanceMeters / Math.max(request.radiusMeters, 1));
  }

  return {
    ...place,
    distanceMeters,
    score: Number(score.toFixed(3)),
    matchedTerms: matchedTerms.size > 0 ? [...matchedTerms] : deriveMatchedTerms(place, request.prompt),
  };
};

export const searchPlaces = (places: PublishedPlace[], request: SearchRequest): SearchResult[] =>
  places
    .map((place) => scorePlace(place, request))
    .filter((place): place is SearchResult => place !== null)
    .sort((left, right) => {
      if (right.score !== left.score) {
        return right.score - left.score;
      }

      const leftDistance = left.distanceMeters ?? Number.POSITIVE_INFINITY;
      const rightDistance = right.distanceMeters ?? Number.POSITIVE_INFINITY;
      if (leftDistance !== rightDistance) {
        return leftDistance - rightDistance;
      }

      return left.name.localeCompare(right.name);
    })
    .slice(0, request.limit);

const readString = (item: Record<string, AttributeValue>, key: string): string => {
  const value = item[key];
  if (!value || value.S === undefined) {
    throw new Error(`Expected string attribute "${key}" on DynamoDB place item.`);
  }

  return value.S;
};

const readNumber = (item: Record<string, AttributeValue>, key: string): number => {
  const value = item[key];
  if (!value || value.N === undefined) {
    throw new Error(`Expected numeric attribute "${key}" on DynamoDB place item.`);
  }

  return Number(value.N);
};

const toPublishedPlace = (item: Record<string, AttributeValue>): PublishedPlace => ({
  id: readString(item, 'id'),
  name: readString(item, 'name'),
  normalizedName: readString(item, 'normalizedName'),
  category: readString(item, 'category'),
  lat: readNumber(item, 'lat'),
  lng: readNumber(item, 'lng'),
  address: readString(item, 'address'),
  sourceNote: readString(item, 'sourceNote'),
});

export const listPublishedPlaces = async (
  tableName: string,
  client: DynamoDBClient = dynamoClient,
): Promise<PublishedPlace[]> => {
  const places: PublishedPlace[] = [];
  let exclusiveStartKey: Record<string, AttributeValue> | undefined;

  do {
    const response = await client.send(
      new QueryCommand({
        TableName: tableName,
        IndexName: GSI1_INDEX_NAME,
        KeyConditionExpression: '#gsi1pk = :entityType',
        FilterExpression: '#status = :published',
        ExpressionAttributeNames: {
          '#gsi1pk': 'GSI1PK',
          '#status': 'status',
        },
        ExpressionAttributeValues: {
          ':entityType': { S: PLACE_ENTITY },
          ':published': { S: PUBLISHED_STATUS },
        },
        ExclusiveStartKey: exclusiveStartKey,
      }),
    );

    (response.Items ?? []).forEach((item) => {
      places.push(toPublishedPlace(item));
    });

    exclusiveStartKey = response.LastEvaluatedKey;
  } while (exclusiveStartKey);

  return places;
};
