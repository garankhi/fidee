import { DefineAuthChallengeTriggerEvent } from 'aws-lambda';

/**
 * Cognito Define Auth Challenge trigger.
 * Controls the Google custom auth flow:
 *  - If no previous challenge → issue CUSTOM_CHALLENGE
 *  - If last challenge answered correctly → allow sign-in
 *  - If the challenge failed → block without retrying as OTP
 */
export const handler = async (
  event: DefineAuthChallengeTriggerEvent,
): Promise<DefineAuthChallengeTriggerEvent> => {
  const { session } = event.request;

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

  // CUSTOM_AUTH is Google-only, so a failed challenge should not retry as OTP.
  event.response.issueTokens = false;
  event.response.failAuthentication = true;
  return event;
};
