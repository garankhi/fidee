import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { extractAuth } from '../middleware/auth';
import { incrementAiUsage, AiUsageResult } from '../repositories/ai-usage';
import { getUserPlan, UserPlan } from '../repositories/user-profiles';

interface SearchDeps {
  getPlan: (userId: string) => Promise<UserPlan>;
  incrementUsage: (input: { userId: string; plan: UserPlan }) => Promise<AiUsageResult>;
}

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  };
}

function defaultDeps(): SearchDeps {
  const userProfilesTable = process.env.USER_PROFILES_TABLE;
  if (!userProfilesTable) {
    throw new Error('USER_PROFILES_TABLE is required');
  }

  return {
    getPlan: (userId) => getUserPlan(userId, userProfilesTable),
    incrementUsage: incrementAiUsage,
  };
}

/**
 * Search handler — accepts a natural language prompt and returns matching places.
 *
 * Flow:
 *  1. Sanitize & validate the prompt
 *  2. Check server-side daily AI quota
 *  3. Check 24h cache in DynamoDB
 *  4. If cache miss → call Amazon Bedrock to extract structured filters
 *  5. Query geo-index with extracted filters
 *  6. Return ranked results
 */
export function createSearchHandler(deps: SearchDeps = defaultDeps()) {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const body = event.body ? JSON.parse(event.body) : {};
    const prompt = body.prompt as string | undefined;

    if (!prompt || prompt.trim().length === 0) {
      return jsonResponse(400, { error: 'Missing required field: prompt' });
    }

    try {
      const auth = await extractAuth(event);
      const plan = await deps.getPlan(auth.sub);
      const quota = await deps.incrementUsage({ userId: auth.sub, plan });

      if (!quota.allowed) {
        return jsonResponse(429, {
          error: 'AI_QUOTA_EXCEEDED',
          limit: quota.limit,
          used: quota.used,
          resetDate: quota.usageDate,
        });
      }

      return jsonResponse(200, {
        message: 'Search endpoint ready',
        prompt: prompt.trim(),
        results: [],
        quota: {
          limit: quota.limit,
          used: quota.used,
          resetDate: quota.usageDate,
        },
      });
    } catch (error) {
      if (error instanceof Error && error.message.startsWith('Missing auth context')) {
        return jsonResponse(401, { error: error.message });
      }

      console.error('Failed to search places', error);
      return jsonResponse(500, { error: 'Internal server error' });
    }
  };
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> =>
  createSearchHandler()(event);
