import { getPool } from './src/db/client';
import { CognitoIdentityProviderClient, AdminGetUserCommand } from '@aws-sdk/client-cognito-identity-provider';

async function main() {
  const pool = await getPool();
  const client = await pool.connect();
  const cognito = new CognitoIdentityProviderClient({ region: 'ap-southeast-1' });
  const userPoolId = 'ap-southeast-1_KSHDSpl6f';
  
  try {
    const emailA = 'chat.test.a@fidee.site';
    const emailB = 'chat.test.b@fidee.site';
    
    // Fetch from cognito
    console.log('Fetching users from Cognito...');
    const cognitoA = await cognito.send(new AdminGetUserCommand({ UserPoolId: userPoolId, Username: emailA }));
    const cognitoB = await cognito.send(new AdminGetUserCommand({ UserPoolId: userPoolId, Username: emailB }));
    
    const getAttr = (attributes: any[], name: string) => attributes.find(a => a.Name === name)?.Value;
    
    const userA = {
      sub: getAttr(cognitoA.UserAttributes || [], 'sub'),
      email: getAttr(cognitoA.UserAttributes || [], 'email'),
      username: cognitoA.Username,
    };
    
    const userB = {
      sub: getAttr(cognitoB.UserAttributes || [], 'sub'),
      email: getAttr(cognitoB.UserAttributes || [], 'email'),
      username: cognitoB.Username,
    };
    
    console.log(`User A sub: ${userA.sub}`);
    console.log(`User B sub: ${userB.sub}`);
    
    await client.query('BEGIN');
    
    // Upsert to postgres users
    await client.query(`
      INSERT INTO users (id, email, username, display_name)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email
    `, [userA.sub, userA.email, 'chat_test_a', 'Chat Test A']);
    
    await client.query(`
      INSERT INTO users (id, email, username, display_name)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email
    `, [userB.sub, userB.email, 'chat_test_b', 'Chat Test B']);
    
    // Insert friendship A -> B
    await client.query(`
      INSERT INTO friendships (user_id, friend_id, status)
      VALUES ($1, $2, 'ACCEPTED')
      ON CONFLICT (user_id, friend_id) DO UPDATE SET status = 'ACCEPTED'
    `, [userA.sub, userB.sub]);
    
    // Insert friendship B -> A
    await client.query(`
      INSERT INTO friendships (user_id, friend_id, status)
      VALUES ($1, $2, 'ACCEPTED')
      ON CONFLICT (user_id, friend_id) DO UPDATE SET status = 'ACCEPTED'
    `, [userB.sub, userA.sub]);
    
    await client.query('COMMIT');
    console.log('Successfully synced User A and User B to PostgreSQL and made them friends (ACCEPTED)!');
    
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
  } finally {
    client.release();
    pool.end();
  }
}

main();
