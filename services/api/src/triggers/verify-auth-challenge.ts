import { VerifyAuthChallengeResponseTriggerEvent } from 'aws-lambda';

/**
 * Cognito Verify Auth Challenge trigger.
 * Compares the user's OTP input with the expected OTP.
 *
 * SECURITY:
 *  - OTP values are NOT logged
 *  - Only the boolean result is returned
 */
export const handler = async (
  event: VerifyAuthChallengeResponseTriggerEvent,
): Promise<VerifyAuthChallengeResponseTriggerEvent> => {
  const expected = event.request.privateChallengeParameters?.answer;
  const provided = event.request.challengeAnswer;

  event.response.answerCorrect = expected === provided;

  return event;
};
