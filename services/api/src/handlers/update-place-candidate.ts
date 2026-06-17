import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';
import { ValidationError } from '../media/validation';
import { CandidateVisibility } from '../repositories/place-candidates';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

type CandidateUpdate = {
  address?: string | null;
  openTime?: string | null;
  closeTime?: string | null;
  priceMin?: number | null;
  priceMax?: number | null;
  phoneNumber?: string | null;
  description?: string | null;
  visibility?: CandidateVisibility;
  mediaId?: string | null;
};

const FIELD_DEFS = [
  ['address', 'address'],
  ['openTime', 'open_time'],
  ['closeTime', 'close_time'],
  ['priceMin', 'price_min'],
  ['priceMax', 'price_max'],
  ['phoneNumber', 'phone_number'],
  ['description', 'description'],
  ['visibility', 'visibility'],
  ['mediaId', 'media_id'],
] as const;

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return { statusCode, headers: CORS_HEADERS, body: JSON.stringify(body) };
}

function hasOwn(body: Record<string, unknown>, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(body, key);
}

function nullableString(body: Record<string, unknown>, key: string): string | null | undefined {
  if (!hasOwn(body, key)) return undefined;
  const value = body[key];
  if (value === null) return null;
  if (typeof value !== 'string') {
    throw new ValidationError(`${key} must be a string or null`);
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function nullableNumber(body: Record<string, unknown>, key: string): number | null | undefined {
  if (!hasOwn(body, key)) return undefined;
  const value = body[key];
  if (value === null) return null;
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new ValidationError(`${key} must be a number or null`);
  }
  return value;
}

function parseVisibility(value: unknown): CandidateVisibility {
  if (value === 'FRIENDS' || value === 'PRIVATE') return value;
  throw new ValidationError('visibility must be FRIENDS or PRIVATE');
}

function parseBody(rawBody: string | null): CandidateUpdate {
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawBody ?? '{}');
  } catch {
    throw new ValidationError('Request body must be valid JSON');
  }

  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw new ValidationError('Request body must be a JSON object');
  }

  const body = parsed as Record<string, unknown>;
  const update: CandidateUpdate = {
    address: nullableString(body, 'address'),
    openTime: nullableString(body, 'openTime'),
    closeTime: nullableString(body, 'closeTime'),
    priceMin: nullableNumber(body, 'priceMin'),
    priceMax: nullableNumber(body, 'priceMax'),
    phoneNumber: nullableString(body, 'phoneNumber'),
    description: nullableString(body, 'description'),
    mediaId: nullableString(body, 'mediaId'),
  };

  if (hasOwn(body, 'visibility')) {
    update.visibility = parseVisibility(body.visibility);
  }

  const hasUpdate = FIELD_DEFS.some(([key]) => update[key] !== undefined);
  if (!hasUpdate) {
    throw new ValidationError('At least one candidate field must be provided');
  }

  return update;
}

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const candidateId = event.pathParameters?.id;
    if (!candidateId) {
      return jsonResponse(400, {
        status: 'error',
        error: { code: 'VALIDATION_ERROR', message: 'Missing candidate id' },
      });
    }

    const update = parseBody(event.body);

    let userId: string;
    try {
      const auth = await extractAuth(event);
      userId = auth.sub;
    } catch {
      return jsonResponse(401, {
        status: 'error',
        error: { code: 'UNAUTHORIZED', message: 'Unauthorized' },
      });
    }

    const existing = await query('SELECT id, created_by FROM place_candidates WHERE id = $1', [
      candidateId,
    ]);
    if (existing.rows.length === 0) {
      return jsonResponse(404, {
        status: 'error',
        error: { code: 'NOT_FOUND', message: 'Candidate not found' },
      });
    }

    if (existing.rows[0].created_by !== userId) {
      return jsonResponse(403, {
        status: 'error',
        error: { code: 'FORBIDDEN', message: 'Only the creator can update this candidate' },
      });
    }

    const setClauses: string[] = [];
    const params: unknown[] = [];
    for (const [key, column] of FIELD_DEFS) {
      const value = update[key];
      if (value === undefined) continue;
      params.push(value);
      setClauses.push(`${column} = $${params.length}`);
    }

    params.push(candidateId);
    const idParam = params.length;
    const updateSql = `
      UPDATE place_candidates
      SET ${setClauses.join(', ')}, updated_at = NOW(), status = 'PENDING_REVIEW'
      WHERE id = $${idParam}
      RETURNING
        id,
        name,
        address,
        open_time,
        close_time,
        price_min,
        price_max,
        phone_number,
        description,
        visibility,
        status,
        updated_at;
    `;

    const updated = await query(updateSql, params);
    const row = updated.rows[0];

    return jsonResponse(200, {
      status: 'success',
      data: {
        id: row.id,
        name: row.name,
        address: row.address,
        open_time: row.open_time,
        close_time: row.close_time,
        price_min: row.price_min,
        price_max: row.price_max,
        phone_number: row.phone_number,
        description: row.description,
        visibility: row.visibility,
        status: row.status,
        updated_at: row.updated_at,
      },
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return jsonResponse(400, {
        status: 'error',
        error: { code: 'VALIDATION_ERROR', message: error.message },
      });
    }

    console.error('Failed to update place candidate:', error);
    return jsonResponse(500, {
      status: 'error',
      error: { code: 'INTERNAL_ERROR', message: 'Internal server error' },
    });
  }
}
