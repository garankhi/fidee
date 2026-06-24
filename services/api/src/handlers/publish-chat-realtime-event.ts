import { Sha256 } from '@aws-crypto/sha256-js';
import { defaultProvider } from '@aws-sdk/credential-provider-node';
import { HttpRequest } from '@smithy/core/transport';
import { SignatureV4 } from '@smithy/signature-v4';
import { DynamoDBStreamEvent } from 'aws-lambda';

interface ChatRealtimePayload {
  eventId: string;
  type: string;
  targetUserId: string;
  conversationId?: string | null;
  message?: Record<string, unknown> | null;
  receipt?: Record<string, unknown> | null;
  typing?: Record<string, unknown> | null;
  presence?: Record<string, unknown> | null;
  createdAt: string;
}

const chatEventTypes = new Set([
  'MESSAGE_CREATED',
  'MESSAGE_DELIVERED',
  'MESSAGE_READ',
  'TYPING',
  'PRESENCE_CHANGED',
]);

export async function handler(event: DynamoDBStreamEvent): Promise<void> {
  for (const record of event.Records) {
    if (record.eventName !== 'INSERT') continue;

    const image = record.dynamodb?.NewImage;
    const type = image?.type?.S ?? '';
    if (!image || !chatEventTypes.has(type)) continue;

    await publishChatRealtimeEvent({
      eventId: image.eventId?.S ?? '',
      type,
      targetUserId: image.targetUserId?.S ?? '',
      conversationId: image.conversationId?.S || null,
      message: parseJsonAttribute(image.message?.S),
      receipt: parseJsonAttribute(image.receipt?.S),
      typing: parseJsonAttribute(image.typing?.S),
      presence: parseJsonAttribute(image.presence?.S),
      createdAt: image.createdAt?.S ?? new Date().toISOString(),
    });
  }
}

function parseJsonAttribute(value: string | undefined): Record<string, unknown> | null {
  if (!value) return null;
  const parsed = JSON.parse(value) as unknown;
  return parsed && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : null;
}

async function publishChatRealtimeEvent(input: ChatRealtimePayload): Promise<void> {
  const graphqlUrl = process.env.FRIEND_REALTIME_GRAPHQL_URL!;
  const region = process.env.AWS_REGION ?? 'ap-southeast-1';
  const url = new URL(graphqlUrl);
  const body = JSON.stringify({
    query: `mutation PublishChatRealtimeEvent($input: PublishChatRealtimeEventInput!) {
      publishChatRealtimeEvent(input: $input) {
        eventId
        type
        targetUserId
        conversationId
        message {
          id
          conversationId
          senderId
          clientMessageId
          body
          status
          createdAt
        }
        receipt {
          conversationId
          messageId
          userId
          deliveredAt
          readAt
        }
        typing {
          conversationId
          userId
          isTyping
        }
        presence {
          userId
          status
          lastSeenAt
        }
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
