import {
  AdminAddUserToGroupCommand,
  AdminCreateUserCommand,
  AdminSetUserPasswordCommand,
  AdminGetUserCommand,
  CognitoIdentityProviderClient,
  UsernameExistsException,
} from '@aws-sdk/client-cognito-identity-provider';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const stage = process.env.STAGE || 'dev';
const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'ap-southeast-1';

const email = process.argv[2];
const password = process.argv[3];
const displayName = process.argv[4] || 'Fidee Admin';

if (!email || !password) {
  console.error('Usage: node create-admin-user.mjs <email> <password> [displayName]');
  process.exit(1);
}

function readJson(path) {
  if (!existsSync(path)) return null;
  const buffer = readFileSync(path);
  let text;

  if (buffer[0] === 0xff && buffer[1] === 0xfe) {
    text = buffer.toString('utf16le');
  } else if (buffer[0] === 0xfe && buffer[1] === 0xff) {
    text = Buffer.from(buffer.subarray(2)).swap16().toString('utf16le');
  } else {
    text = buffer.toString('utf8');
  }

  return JSON.parse(text.replace(/^\uFEFF/, '').replace(/\u0000/g, '').trim());
}

function findOutputValue(outputs, key) {
  if (Array.isArray(outputs)) {
    const match = outputs.find((output) => output?.OutputKey === key);
    return match?.OutputValue || null;
  }

  for (const stackOutputs of Object.values(outputs || {})) {
    if (stackOutputs && typeof stackOutputs === 'object' && key in stackOutputs) {
      return stackOutputs[key];
    }
  }
  return null;
}

function resolveUserPoolId() {
  if (process.env.USER_POOL_ID) return process.env.USER_POOL_ID;

  const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
  const candidates = [
    resolve(repoRoot, `cdk-outputs-${stage}-full.json`),
    resolve(repoRoot, `cdk-outputs-${stage}.json`),
    resolve(repoRoot, 'cdk-outputs.json'),
  ];

  for (const candidate of candidates) {
    const outputs = readJson(candidate);
    const userPoolId = findOutputValue(outputs, 'UserPoolId');
    if (typeof userPoolId === 'string' && userPoolId.length > 0) {
      return userPoolId;
    }
  }

  return null;
}

function assertInput(value, name) {
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}

const userPoolId = assertInput(resolveUserPoolId(), 'USER_POOL_ID');

const client = new CognitoIdentityProviderClient({ region });

async function createOrUpdateAdminUser() {
  let sub = null;

  try {
    const createRes = await client.send(
      new AdminCreateUserCommand({
        UserPoolId: userPoolId,
        Username: email,
        MessageAction: 'SUPPRESS',
        UserAttributes: [
          { Name: 'email', Value: email },
          { Name: 'email_verified', Value: 'true' },
          { Name: 'name', Value: displayName },
        ],
      }),
    );
    console.log(`Created Cognito user ${email}`);
    sub = createRes.User?.Attributes?.find(a => a.Name === 'sub')?.Value;
  } catch (error) {
    if (error instanceof UsernameExistsException || error?.name === 'UsernameExistsException') {
      console.log(`Cognito user ${email} already exists, updating password/group`);
    } else {
      throw error;
    }
  }

  if (!sub) {
    const getRes = await client.send(
      new AdminGetUserCommand({
        UserPoolId: userPoolId,
        Username: email,
      })
    );
    sub = getRes.UserAttributes?.find(a => a.Name === 'sub')?.Value;
  }

  await client.send(
    new AdminSetUserPasswordCommand({
      UserPoolId: userPoolId,
      Username: email,
      Password: password,
      Permanent: true,
    }),
  );

  await client.send(
    new AdminAddUserToGroupCommand({
      UserPoolId: userPoolId,
      Username: email,
      GroupName: 'Admins',
    }),
  );

  console.log(`Admin account ready in Cognito: ${email}`);
  console.log(`UserPoolId: ${userPoolId}`);
  console.log(`User Sub: ${sub}`);

  // Insert to PostgreSQL
  const dbPassword = process.env.DB_PASSWORD || 'N9ir4EXjWoJkTDmAcHqLA=M,I4KiYv';
  const pgClient = new pg.Client({
    host: 'localhost',
    port: 5433,
    database: 'fidee',
    user: 'postgres',
    password: dbPassword,
  });

  try {
    await pgClient.connect();
    const sql = `
      INSERT INTO users (id, email, display_name, plan)
      VALUES ($1, $2, $3, 'FREE')
      ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        display_name = EXCLUDED.display_name;
    `;
    await pgClient.query(sql, [sub, email, displayName]);
    console.log(`Successfully synced admin user ${email} to PostgreSQL database!`);
  } catch (err) {
    console.error('Failed to sync user to PostgreSQL. Is the SSM tunnel open on port 5433?');
    console.error(err);
  } finally {
    await pgClient.end();
  }
}

createOrUpdateAdminUser().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
