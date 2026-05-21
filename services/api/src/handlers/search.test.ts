import { describe, it, expect } from 'vitest';
import { handler } from './search';
import { APIGatewayProxyEvent } from 'aws-lambda';

const mockEvent = (body: Record<string, unknown> | null): APIGatewayProxyEvent =>
  ({
    body: body ? JSON.stringify(body) : null,
    headers: {},
    multiValueHeaders: {},
    httpMethod: 'POST',
    isBase64Encoded: false,
    path: '/search',
    pathParameters: null,
    queryStringParameters: null,
    multiValueQueryStringParameters: null,
    stageVariables: null,
    requestContext: {} as APIGatewayProxyEvent['requestContext'],
    resource: '',
  }) as APIGatewayProxyEvent;

describe('search handler', () => {
  it('returns 400 when prompt is missing', async () => {
    const result = await handler(mockEvent(null));
    expect(result.statusCode).toBe(400);
  });

  it('returns 200 with valid prompt', async () => {
    const result = await handler(mockEvent({ prompt: 'rooftop restaurant' }));
    expect(result.statusCode).toBe(200);
    const body = JSON.parse(result.body);
    expect(body.prompt).toBe('rooftop restaurant');
  });
});
