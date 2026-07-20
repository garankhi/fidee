import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { extractAuth, requireAdmin } from '../../middleware/auth';

export async function requireAdminFromEvent(event: APIGatewayProxyEvent): Promise<string | APIGatewayProxyResult> {
  try {
    const auth = await extractAuth(event);
    requireAdmin(auth);
    return auth.sub;
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unauthorized';
    const isForbidden = message.startsWith('Forbidden');

    return {
      statusCode: isForbidden ? 403 : 401,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
      body: JSON.stringify({
        error: isForbidden ? 'Forbidden' : 'Unauthorized',
      }),
    };
  }
}

export function isAuthResponse(value: string | APIGatewayProxyResult): value is APIGatewayProxyResult {
  return typeof value !== 'string';
}
