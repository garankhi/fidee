import { PreSignUpTriggerEvent } from 'aws-lambda';

/**
 * Cognito Pre Sign-Up trigger.
 * Auto-confirms new users so they don't need a separate confirmation step.
 * Phone/email verification is handled via the OTP challenge flow.
 */
export const handler = async (
  event: PreSignUpTriggerEvent,
): Promise<PreSignUpTriggerEvent> => {
  event.response.autoConfirmUser = true;

  if (event.request.userAttributes.phone_number) {
    event.response.autoVerifyPhone = true;
  }
  if (event.request.userAttributes.email) {
    event.response.autoVerifyEmail = true;
  }

  return event;
};
