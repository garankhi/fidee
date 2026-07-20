import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  AdminPlaceValidationError,
  getAdminId,
  insertAdminPlace,
  isAuthResponse,
  jsonResponse,
  parsePlaceRequest,
} from './places-common';

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const adminId = await getAdminId(event);
    if (isAuthResponse(adminId)) return adminId;

    const request = parsePlaceRequest(event.body);
    const place = await insertAdminPlace(request, adminId);
    return jsonResponse(201, { status: 'success', data: place });
  } catch (error) {
    if (error instanceof AdminPlaceValidationError) {
      return jsonResponse(400, { error: error.message });
    }
    console.error('Error creating admin place:', error);
    return jsonResponse(500, { error: 'Internal Server Error' });
  }
}
