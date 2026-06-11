import { Sha256 } from '@aws-crypto/sha256-js';
import { defaultProvider } from '@aws-sdk/credential-provider-node';
import { HttpRequest } from '@aws-sdk/protocol-http';
import { SignatureV4 } from '@aws-sdk/signature-v4';
import { DynamoDBStreamEvent } from 'aws-lambda';

interface FriendRealtimePayload {
  eventId: string;
  type: string;
  targetUserId: string;
  requesterId: string;
  requesterName: string;
  requesterUsername: string;
  requesterAvatarUrl: string;
  createdAt: string;
}

export async function handler(event: DynamoDBStreamEvent): Promise<void> {
  for (const record of event.Records) {
    if (record.eventName !== 'INSERT') continue;

    const image = record.dynamodb?.NewImage;
    if (!image || image.type?.S !== 'FRIEND_REQUEST_RECEIVED') continue;

    await publishFriendRequestReceived({
      eventId: image.eventId?.S ?? '',
      type: image.type.S,
      targetUserId: image.targetUserId?.S ?? '',
      requesterId: image.requesterId?.S ?? '',
      requesterName: image.requesterName?.S ?? 'Một người bạn',
      requesterUsername: image.requesterUsername?.S ?? '',
      requesterAvatarUrl: image.requesterAvatarUrl?.S ?? '',
      createdAt: image.createdAt?.S ?? new Date().toISOString(),
    });
  }
}

async function publishFriendRequestReceived(input: FriendRealtimePayload): Promise<void> {
  const graphqlUrl = process.env.FRIEND_REALTIME_GRAPHQL_URL!;
  const region = process.env.AWS_REGION ?? 'ap-southeast-1';
  const url = new URL(graphqlUrl);
  const body = JSON.stringify({
    query: `mutation PublishFriendRequestReceived($input: PublishFriendRequestReceivedInput!) {
      publishFriendRequestReceived(input: $input) {
        eventId
        type
        targetUserId
        requesterId
        requesterName
        requesterUsername
        requesterAvatarUrl
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
}
