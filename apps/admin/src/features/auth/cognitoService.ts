import {
  CognitoUserPool,
  CognitoUser,
  AuthenticationDetails,
  CognitoUserSession,
} from 'amazon-cognito-identity-js';

const poolData = {
  UserPoolId: (import.meta.env.VITE_COGNITO_USER_POOL_ID as string) || '',
  ClientId: (import.meta.env.VITE_COGNITO_CLIENT_ID as string) || '',
};

export const userPool = new CognitoUserPool(poolData);

function parseJwtPayload(token: string): Record<string, unknown> | null {
  const [, payload] = token.split('.');
  if (!payload) return null;

  try {
    const normalizedPayload = payload.replace(/-/g, '+').replace(/_/g, '/');
    const json = atob(normalizedPayload.padEnd(Math.ceil(normalizedPayload.length / 4) * 4, '='));
    return JSON.parse(json) as Record<string, unknown>;
  } catch {
    return null;
  }
}

export function tokenHasAdminGroup(token: string): boolean {
  const payload = parseJwtPayload(token);
  const groups = payload?.['cognito:groups'];

  if (Array.isArray(groups)) {
    return groups.includes('Admins');
  }

  return typeof groups === 'string' && groups.split(',').includes('Admins');
}

function clearAdminAuthStorage(): void {
  localStorage.removeItem('admin_token');

  const cognitoPrefix = `CognitoIdentityServiceProvider.${poolData.ClientId}`;
  for (let i = localStorage.length - 1; i >= 0; i -= 1) {
    const key = localStorage.key(i);
    if (key?.startsWith(cognitoPrefix)) {
      localStorage.removeItem(key);
    }
  }
}

/**
 * Đăng nhập Admin vào AWS Cognito User Pool.
 * Lấy ra token JWT (Access Token hoặc ID Token) thô và lưu vào LocalStorage.
 */
export function loginAdmin(email: string, password: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const authenticationData = {
      Username: email,
      Password: password,
    };
    const authenticationDetails = new AuthenticationDetails(authenticationData);

    const userData = {
      Username: email,
      Pool: userPool,
    };
    const cognitoUser = new CognitoUser(userData);

    cognitoUser.authenticateUser(authenticationDetails, {
      onSuccess: (session: CognitoUserSession) => {
        // Lấy token thô. API Gateway Cognito Authorizer chấp nhận ID Token hoặc Access Token
        // Ở đây lấy ID Token (chứa email, groups, v.v.) hoặc Access Token đều được.
        const idToken = session.getIdToken().getJwtToken();
        if (!tokenHasAdminGroup(idToken)) {
          clearAdminAuthStorage();
          reject(new Error('Tài khoản này chưa thuộc nhóm Admins.'));
          return;
        }
        
        // Lưu token vào localStorage
        localStorage.setItem('admin_token', idToken);
        resolve(idToken);
      },
      onFailure: (err) => {
        reject(err);
      },
      newPasswordRequired: () => {
        reject(new Error('Yêu cầu đổi mật khẩu mới (Chưa được cấu hình cho tài khoản này)'));
      },
    });
  });
}

/**
 * Đăng xuất Admin. Xóa token khỏi LocalStorage.
 */
export function logoutAdmin(): void {
  try {
    const currentUser = userPool.getCurrentUser();
    if (currentUser) {
      currentUser.signOut();
    }
  } catch (error) {
    console.error('Error during Cognito signOut:', error);
  } finally {
    clearAdminAuthStorage();
  }
}

/**
 * Kiểm tra xem admin đã đăng nhập chưa bằng cách kiểm tra sự tồn tại của token
 */
export function isAuthenticated(): boolean {
  const token = localStorage.getItem('admin_token');
  return !!token && tokenHasAdminGroup(token);
}
