import { DefineAuthChallengeTriggerEvent } from 'aws-lambda';

/**
 * Cognito Define Auth Challenge trigger.
 * Controls the custom auth flow:
 *  - If no previous challenge → issue CUSTOM_CHALLENGE
 *  - If last challenge answered correctly → allow sign-in
 *  - If 5+ failed attempts → block (Cognito handles lockout)
 */
export const handler = async (
  event: DefineAuthChallengeTriggerEvent,
): Promise<DefineAuthChallengeTriggerEvent> => {
  const { session } = event.request;
  const isGoogle = true; // Google is the only provider using CUSTOM_AUTH flow

  if (session.length === 0) {
    // First call — issue a custom challenge (OTP or Google)
    event.response.issueTokens = false;
    event.response.failAuthentication = false;
    event.response.challengeName = 'CUSTOM_CHALLENGE';
    return event;
  }

  const lastChallenge = session[session.length - 1];

  if (lastChallenge.challengeResult) {
    // verified successfully — issue tokens
    event.response.issueTokens = true;
    event.response.failAuthentication = false;
    return event;
  }

  // If Google verification failed, fail authentication immediately (no retries)
  if (isGoogle || lastChallenge.challengeMetadata?.includes('GOOGLE')) {
    event.response.issueTokens = false;
    event.response.failAuthentication = true;
    return event;
  }

  // OTP verification failed
  const failedAttempts = session.filter((s) => !s.challengeResult).length;

  if (failedAttempts >= 5) {
    // Too many failed attempts — block authentication
    event.response.issueTokens = false;
    event.response.failAuthentication = true;
    return event;
  }

  // Allow retry (OTP only)
  event.response.issueTokens = false;
  event.response.failAuthentication = false;
  event.response.challengeName = 'CUSTOM_CHALLENGE';
  return event;
};
