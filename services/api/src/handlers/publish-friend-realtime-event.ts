import { Sha256 } from '@aws-crypto/sha256-js';
import { defaultProvider } from '@aws-sdk/credential-provider-node';
import { HttpRequest } from '@aws-sdk/protocol-http';
import { SignatureV4 } from '@aws-sdk/signature-v4';
import { DynamoDBStreamEvent } from 'aws-lambda';

const friendRealtimeEventTypes = new Set([
  'FRIEND_REQUEST_RECEIVED',
  'FRIEND_REQUEST_CANCELED',
  'FRIEND_REQUEST_DECLINED',
  'FRIEND_REQUEST_ACCEPTED',
  'FRIENDSHIP_REMOVED',
  'FRIENDSHIP_HIDDEN',
  'FRIEND_BLOCKED',
]);

interface FriendRealtimePayload {
  eventId: string;
  type: string;
  targetUserId: string;
  actorUserId: string;
  relatedUserId: string;
  actorName: string;
  actorUsername: string;
  actorAvatarUrl: string;
  createdAt: string;
}

export async function handler(event: DynamoDBStreamEvent): Promise<void> {
  for (const record of event.Records) {
    if (record.eventName !== 'INSERT') continue;

    const image = record.dynamodb?.NewImage;
    const eventType = image?.type?.S;
    if (!image || !eventType || !friendRealtimeEventTypes.has(eventType)) {
      continue;
    }

    await publishFriendRealtimeEvent({
      eventId: image.eventId?.S ?? '',
      type: eventType,
      targetUserId: image.targetUserId?.S ?? '',
      actorUserId: image.actorUserId?.S ?? image.requesterId?.S ?? '',
      relatedUserId: image.relatedUserId?.S ?? image.requesterId?.S ?? image.actorUserId?.S ?? '',
      actorName: image.actorName?.S ?? image.requesterName?.S ?? 'Một người bạn',
      actorUsername: image.actorUsername?.S ?? image.requesterUsername?.S ?? '',
      actorAvatarUrl: image.actorAvatarUrl?.S ?? image.requesterAvatarUrl?.S ?? '',
      createdAt: image.createdAt?.S ?? new Date().toISOString(),
    });
  }
}

async function publishFriendRealtimeEvent(input: FriendRealtimePayload): Promise<void> {
  const graphqlUrl = process.env.FRIEND_REALTIME_GRAPHQL_URL!;
  const region = process.env.AWS_REGION ?? 'ap-southeast-1';
  const url = new URL(graphqlUrl);
  const body = JSON.stringify({
    query: `mutation PublishFriendRealtimeEvent($input: PublishFriendRealtimeEventInput!) {
      publishFriendRealtimeEvent(input: $input) {
        eventId
        type
        targetUserId
        actorUserId
        relatedUserId
        actorName
        actorUsername
        actorAvatarUrl
        createdAt
      }
    }`,
    variables: { input },
  });

  const signer = new SignatureV4({
    credentials: defaultProvider(),
    region,
    service: 'appsync',
    sha256: Sha256,
  });
  const request = new HttpRequest({
    method: 'POST',
    protocol: url.protocol,
    hostname: url.hostname,
    path: url.pathname,
    headers: {
      host: url.hostname,
      'content-type': 'application/json',
    },
    body,
  });
  const signed = await signer.sign(request);
  const response = await fetch(graphqlUrl, {
    method: 'POST',
    headers: signed.headers as Record<string, string>,
    body,
  });

  if (!response.ok) {
    throw new Error(`AppSync publish failed: ${response.status}`);
  }

  const responseBody = (await response.json()) as {
    errors?: Array<{ message?: string }>;
  };
  if (responseBody.errors?.length) {
    const message = responseBody.errors.map((error) => error.message ?? 'Unknown error').join('; ');
    throw new Error(`AppSync publish failed: ${message}`);
  }
}
