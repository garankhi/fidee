import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  listPublishedPlaces,
  parseSearchRequest,
  searchPlaces,
  SearchRequestError,
} from './search-core';

const PLACES_TABLE = process.env.PLACES_TABLE ?? '';

const JSON_HEADERS = { 'Content-Type': 'application/json' };

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  let body: unknown;
  try {
    body = event.body ? JSON.parse(event.body) : {};
  } catch {
    return { statusCode: 400, headers: JSON_HEADERS, body: JSON.stringify({ error: 'Invalid JSON body' }) };
  }

  let request;
  try {
    request = parseSearchRequest(body);
  } catch (error) {
    if (error instanceof SearchRequestError) {
      return { statusCode: 400, headers: JSON_HEADERS, body: JSON.stringify({ error: error.message }) };
    }
    throw error;
  }

  const places = await listPublishedPlaces(PLACES_TABLE);
  const results = searchPlaces(places, request);

  return {
    statusCode: 200,
    headers: JSON_HEADERS,
    body: JSON.stringify({ results, total: results.length }),
  };
};
