import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb';

const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

/**
 * PUT /admin/users/{userId}
 * Updates a user's details in PostgreSQL.
 * Protected by Cognito JWT Authorizer.
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    // 1. Get userId from path parameters
    const userId = event.pathParameters?.userId;
    if (!userId) {
      return {
        statusCode: 400,
        headers: { 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ error: 'Missing userId in path' }),
      };
    }

    // 2. Parse request body
    if (!event.body) {
      return {
        statusCode: 400,
        headers: { 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ error: 'Missing request body' }),
      };
    }

    const data = JSON.parse(event.body);
    const { fullName, phone, email, license } = data;

    if (!fullName || !email) {
      return {
        statusCode: 400,
        headers: { 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ error: 'fullName and email are required' }),
      };
    }

    // Map license ('Pro' | 'Enterprise' | 'Free' | 'Basic') to PostgreSQL ENUM plan ('FREE' | 'PRO')
    const dbPlan = license === 'Pro' || license === 'Enterprise' ? 'PRO' : 'FREE';

    // 3. Update database
    const sql = `
      UPDATE users
      SET 
        display_name = $1,
        phone = $2,
        email = $3,
        plan = $4
      WHERE id = $5
      RETURNING 
        id, 
        username, 
        display_name as "fullName", 
        email, 
        phone, 
        created_at as "joinedDate", 
        plan as "license", 
        place_count as "contributions";
    `;

    const result = await query(sql, [fullName, phone || null, email, dbPlan, userId]);

    if (result.rowCount === 0) {
      return {
        statusCode: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    const updatedUser = result.rows[0];

    // Đồng bộ gói cước sang DynamoDB để Mobile App nhận diện chính xác hạn mức
    const userProfilesTable = process.env.USER_PROFILES_TABLE;
    if (userProfilesTable) {
      try {
        await dynamoClient.send(
          new UpdateCommand({
            TableName: userProfilesTable,
            Key: { userId },
            UpdateExpression:
              'SET #plan = :plan, displayName = :displayName, updatedAt = :updatedAt',
            ExpressionAttributeNames: {
              '#plan': 'plan',
            },
            ExpressionAttributeValues: {
              ':plan': dbPlan,
              ':displayName': fullName,
              ':updatedAt': new Date().toISOString(),
            },
          }),
        );
      } catch (dynamoError) {
        console.error('Lỗi đồng bộ gói cước sang DynamoDB:', dynamoError);
        // Không block tiến trình chính nếu ghi DynamoDB gặp sự cố
      }
    }

    const mappedUser = {
      ...updatedUser,
      license: updatedUser.license === 'PRO' ? 'Pro' : 'Free',
      role: data.role || 'User', // Keep role from request or default
      status: data.status || 'active', // Keep status
      joinedDate: new Date(updatedUser.joinedDate as string).toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
      }),
    };

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'PUT,OPTIONS',
      },
      body: JSON.stringify(mappedUser),
    };
  } catch (error) {
    console.error('Error updating user:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
