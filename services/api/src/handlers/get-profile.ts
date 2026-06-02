import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { extractAuth, maskPhone, maskEmail } from '../middleware/auth';

/**
 * GET /profile — returns the authenticated user's profile from JWT claims.
 * Protected by Cognito JWT Authorizer.
 *
 * Returns: { sub, phone (masked), email (masked), groups }
 */
export const handler = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        sub: auth.sub,
        phone: auth.phone ? maskPhone(auth.phone) : null,
        email: auth.email ? maskEmail(auth.email) : null,
        groups: auth.groups,
      }),
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unauthorized';
    const statusCode = message.startsWith('Forbidden') ? 403 : 401;

    return {
      statusCode,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: message }),
    };
  }
};
