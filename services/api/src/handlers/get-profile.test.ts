import { describe, it, expect } from 'vitest';
import { handler } from './get-profile';
import { APIGatewayProxyEvent } from 'aws-lambda';

const mockEvent = (claims: Record<string, string | undefined> | null): APIGatewayProxyEvent =>
  ({
    requestContext: claims ? { authorizer: { claims } } : { authorizer: null },
    headers: {},
    body: null,
    httpMethod: 'GET',
    isBase64Encoded: false,
    path: '/profile',
    pathParameters: null,
    queryStringParameters: null,
    multiValueQueryStringParameters: null,
    multiValueHeaders: {},
    stageVariables: null,
    resource: '',
  }) as unknown as APIGatewayProxyEvent;

describe('get-profile handler', () => {
  it('returns 200 with masked profile for authenticated user', async () => {
    const result = await handler(
      mockEvent({
        sub: 'user-abc',
        phone_number: '+84912345678',
        email: 'test@example.com',
        'cognito:groups': 'Users',
      }),
    );
    expect(result.statusCode).toBe(200);
    const body = JSON.parse(result.body);
    expect(body.sub).toBe('user-abc');
    expect(body.phone).toBe('+84912***678');
    expect(body.email).toBe('te***@example.com');
    expect(body.groups).toEqual(['Users']);
  });

  it('returns 401 when auth context is missing', async () => {
    const result = await handler(mockEvent(null));
    expect(result.statusCode).toBe(401);
  });

  it('returns profile with phone only', async () => {
    const result = await handler(
      mockEvent({
        sub: 'user-phone',
        phone_number: '+84999888777',
        'cognito:groups': 'Moderators',
      }),
    );
    expect(result.statusCode).toBe(200);
    const body = JSON.parse(result.body);
    expect(body.phone).toBe('+84999***777');
    expect(body.email).toBeNull();
    expect(body.groups).toEqual(['Moderators']);
  });
});
