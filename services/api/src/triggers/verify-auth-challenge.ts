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
  const isGoogle = event.request.privateChallengeParameters?.provider === 'google';

  if (isGoogle) {
    const idToken = event.request.challengeAnswer;
    const email = event.request.userAttributes.email;
    const googleClientId = process.env.GOOGLE_CLIENT_ID;

    if (!idToken) {
      console.error('[Verify Auth] Google idToken is missing in challenge answer');
      event.response.answerCorrect = false;
      return event;
    }

    if (!googleClientId) {
      console.error('[Verify Auth] GOOGLE_CLIENT_ID env variable is not configured');
      event.response.answerCorrect = false;
      return event;
    }

    try {
      const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`);
      if (!response.ok) {
        console.error('[Verify Auth] Google tokeninfo API returned error status:', response.status);
        event.response.answerCorrect = false;
        return event;
      }

      const tokenInfo = (await response.json()) as {
        aud?: string;
        email?: string;
        email_verified?: string | boolean;
      };

      const isAudValid = tokenInfo.aud === googleClientId;
      const isEmailValid = tokenInfo.email && tokenInfo.email.toLowerCase() === email.toLowerCase();
      const isEmailVerified = tokenInfo.email_verified === 'true' || tokenInfo.email_verified === true;

      if (isAudValid && isEmailValid && isEmailVerified) {
        console.log('[Verify Auth] Google token verified successfully for', email);
        event.response.answerCorrect = true;
      } else {
        console.warn('[Verify Auth] Google token mismatch:', {
          isAudValid,
          isEmailValid,
          isEmailVerified,
          email,
          tokenEmail: tokenInfo.email,
        });
        event.response.answerCorrect = false;
      }
    } catch (err) {
      console.error('[Verify Auth] Google token verification error:', err);
      event.response.answerCorrect = false;
    }

    return event;
  }

  // OTP Flow
  const expected = event.request.privateChallengeParameters?.answer;
  const provided = event.request.challengeAnswer;

  event.response.answerCorrect = expected === provided;

  return event;
};
