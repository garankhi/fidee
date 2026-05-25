import { CreateAuthChallengeTriggerEvent } from 'aws-lambda';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';

const sns = new SNSClient({});
const ses = new SESClient({});

function generateOtp(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Cognito Create Auth Challenge trigger.
 * Generates a 6-digit OTP and sends it via SMS (phone) or Email (email).
 *
 * SECURITY:
 *  - OTP is NOT logged
 *  - OTP is NOT stored in any database
 *  - OTP only lives in Cognito session as privateChallengeParameters
 */
export const handler = async (
  event: CreateAuthChallengeTriggerEvent,
): Promise<CreateAuthChallengeTriggerEvent> => {
  const otp = generateOtp();

  const phoneNumber = event.request.userAttributes.phone_number;
  const email = event.request.userAttributes.email;

  // Debug: log which attributes are available (never log OTP or raw values)
  console.log('Auth challenge requested', {
    hasPhone: !!phoneNumber,
    hasEmail: !!email,
    username: event.userName ? '***' : 'none',
  });

  if (phoneNumber) {
    try {
      await sns.send(
        new PublishCommand({
          PhoneNumber: phoneNumber,
          Message: `MapVibe: Ma xac thuc cua ban la ${otp}. Hieu luc 5 phut.`,
          MessageAttributes: {
            'AWS.SNS.SMS.SMSType': {
              DataType: 'String',
              StringValue: 'Transactional',
            },
          },
        }),
      );
      console.log('SMS sent successfully');
    } catch (err) {
      console.error('SMS send failed:', err);
      throw err;
    }
  } else if (email) {
    const senderEmail = process.env.SES_SENDER_EMAIL || 'noreply@mapvibe.com';
    try {
      await ses.send(
        new SendEmailCommand({
          Source: senderEmail,
          Destination: { ToAddresses: [email] },
          Message: {
            Subject: { Data: 'MapVibe - Ma xac thuc' },
            Body: {
              Text: { Data: `MapVibe: Ma xac thuc cua ban la ${otp}. Hieu luc 5 phut.` },
            },
          },
        }),
      );
      console.log('Email sent successfully');
    } catch (err) {
      console.error('Email send failed:', err);
      throw err;
    }
  } else {
    console.warn('No phone or email found for user');
  }

  event.response.publicChallengeParameters = {
    // Masked info so the client knows where OTP was sent
    destination: phoneNumber
      ? phoneNumber.replace(/.(?=.{4})/g, '*')
      : email
        ? email.replace(/(.{2}).*(@.*)/, '$1***$2')
        : 'unknown',
  };

  // OTP stored ONLY in Cognito session — never logged, never persisted
  event.response.privateChallengeParameters = { answer: otp };
  event.response.challengeMetadata = `OTP-${Date.now()}`;

  return event;
};
