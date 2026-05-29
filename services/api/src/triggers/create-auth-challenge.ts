import { CreateAuthChallengeTriggerEvent } from 'aws-lambda';
import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY || 're_dummy');

function generateOtp(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Cognito Create Auth Challenge trigger.
 */
export const handler = async (
  event: CreateAuthChallengeTriggerEvent,
): Promise<CreateAuthChallengeTriggerEvent> => {
  const otp = generateOtp();
  const email = event.request.userAttributes.email;

  console.log('Auth challenge requested', {
    hasEmail: !!email,
    username: event.userName ? '***' : 'none',
  });

  if (email) {
    const senderEmail = process.env.RESEND_SENDER_EMAIL || 'onboarding@resend.dev';
    try {
      await resend.emails.send({
        from: senderEmail,
        to: email,
        subject: 'Fidee - Mã xác thực',
        text: 'Fidee: Mã xác thực của bạn là ' + otp + '. Hieu luc 5 phut.',
      });
      console.log('Email sent successfully');
    } catch (err) {
      console.error('Email send failed:', err);
      throw err;
    }
  } else {
    console.warn('No email found for user');
    throw new Error('Email is required for authentication');
  }

  event.response.publicChallengeParameters = {
    destination: email.replace(/(.{2}).*(@.*)/, '$1***$2'),
  };

  event.response.privateChallengeParameters = { answer: otp };
  event.response.challengeMetadata = 'OTP-' + Date.now();

  return event;
};
