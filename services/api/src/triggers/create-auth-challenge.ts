import { CreateAuthChallengeTriggerEvent } from 'aws-lambda';

/**
 * Cognito Create Auth Challenge trigger.
 * CUSTOM_AUTH is only used by mobile Google sign-in in this app.
 */
export const handler = async (
  event: CreateAuthChallengeTriggerEvent,
): Promise<CreateAuthChallengeTriggerEvent> => {
  const email = event.request.userAttributes.email;

  console.log('Auth challenge requested', {
    hasEmail: !!email,
    provider: 'google',
    username: event.userName ? '***' : 'none',
  });

  event.response.publicChallengeParameters = { provider: 'google' };
  event.response.privateChallengeParameters = { provider: 'google' };
  event.response.challengeMetadata = 'GOOGLE_TOKEN';
  return event;
};
