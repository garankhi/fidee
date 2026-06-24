import { PreSignUpTriggerEvent } from 'aws-lambda';

/**
 * Cognito Pre Sign-Up trigger.
 * Email/password users must stay unconfirmed so Cognito sends confirmation codes.
 * Google users are verified by the custom auth challenge, then auto-confirmed here.
 */
export const handler = async (event: PreSignUpTriggerEvent): Promise<PreSignUpTriggerEvent> => {
  const provider = event.request.clientMetadata?.provider;

  if (provider === 'google') {
    event.response.autoConfirmUser = true;
    event.response.autoVerifyEmail = true;
  }

  return event;
};
