import { APIGatewayProxyEvent } from 'aws-lambda';
import { syncUserToDatabases } from '../utils/sync-user';

export interface AuthContext {
  /** Cognito user ID */
  sub: string;
  /** Phone number (raw from JWT claim) */
  phone: string | undefined;
  /** Email (raw from JWT claim) */
  email: string | undefined;
  /** Cognito groups: ['Users'] | ['Moderators'] | ['Admins'] */
  groups: string[];
}

/**
 * Masks a phone number for safe logging.
 * +84912345678 → +84912***678
 */
export function maskPhone(phone: string): string {
  if (phone.length <= 7) return '***';
  return phone.slice(0, -6) + '***' + phone.slice(-3);
}

/**
 * Masks an email for safe logging.
 * user@example.com → us***@example.com
 */
export function maskEmail(email: string): string {
  return email.replace(/(.{2}).*(@.*)/, '$1***$2');
}

/**
 * Extracts auth context from Cognito JWT claims in API Gateway event.
 *
 * SECURITY:
 *  - Never log the raw phone number or email
 *  - Never log the Authorization header or tokens
 *  - Use maskPhone() / maskEmail() for logging
 */
export async function extractAuth(event: APIGatewayProxyEvent): Promise<AuthContext> {
  const claims = event.requestContext.authorizer?.claims;

  if (!claims?.sub) {
    throw new Error('Missing auth context: no sub claim found');
  }

  const sub = claims.sub as string;
  const email = (claims.email as string) || undefined;
  const phone = (claims.phone_number as string) || undefined;

  const groupsClaim = claims['cognito:groups'];
  const groups: string[] = groupsClaim
    ? typeof groupsClaim === 'string'
      ? groupsClaim.split(',')
      : []
    : ['Users'];

  const givenName = claims.given_name as string | undefined;
  const familyName = claims.family_name as string | undefined;
  const preferredUsername = claims.preferred_username as string | undefined;

  // Tự động đồng bộ thông tin profile mới nhất từ JWT token claims sang DB
  try {
    await syncUserToDatabases({
      sub,
      email,
      phone,
      givenName,
      familyName,
      preferredUsername,
    });
  } catch (err) {
    console.error(`[Auth Middleware] Failed to auto-sync user ${sub}:`, err);
  }

  return {
    sub,
    phone,
    email,
    groups,
  };
}

/**
 * Checks if the authenticated user belongs to a required group.
 * Throws an error if not authorized.
 */
export function requireGroup(auth: AuthContext, requiredGroup: string): void {
  if (!auth.groups.includes(requiredGroup)) {
    throw new Error(`Forbidden: requires ${requiredGroup} role`);
  }
}

/**
 * Checks if the user is at least a moderator (Moderators or Admins).
 */
export function requireModerator(auth: AuthContext): void {
  if (!auth.groups.includes('Moderators') && !auth.groups.includes('Admins')) {
    throw new Error('Forbidden: requires Moderator or Admin role');
  }
}

/**
 * Checks if the user is an admin.
 */
export function requireAdmin(auth: AuthContext): void {
  requireGroup(auth, 'Admins');
}
