import React, { useState } from 'react';
import { loginAdmin } from './cognitoService';
import { navigateToPath } from '../../navigation';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setErrorMsg('Vui lòng điền đầy đủ email và mật khẩu.');
      return;
    }

    setIsLoading(true);
    setErrorMsg(null);

    try {
      await loginAdmin(email, password);
      // Đăng nhập thành công, điều hướng về trang chủ
      navigateToPath('/admin');
    } catch (err: any) {
      console.error('Đăng nhập thất bại:', err);
      // Chuyển đổi mã lỗi Cognito sang tiếng Việt thân thiện hơn
      let message = err.message || 'Đã xảy ra lỗi không xác định.';
      if (err.code === 'NotAuthorizedException') {
        message = 'Tên đăng nhập hoặc mật khẩu không chính xác.';
      } else if (err.code === 'UserNotFoundException') {
        message = 'Tài khoản này không tồn tại trên hệ thống.';
      } else if (err.code === 'UserNotConfirmedException') {
        message = 'Tài khoản chưa được xác nhận. Vui lòng kiểm tra email của bạn.';
      }
      setErrorMsg(message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="login-container">
      {/* Các vòng tròn ánh sáng chuyển động nền */}
      <div className="background-glow bg-glow-1"></div>
      <div className="background-glow bg-glow-2"></div>

      <div className="login-card">
        <div className="login-header">
          <div className="login-logo">
            <span>🗺️</span>
          </div>
          <h2>Fidee Admin</h2>
          <p>Hệ thống Quản trị Bản đồ & Khám phá địa điểm</p>
        </div>

        <form onSubmit={handleSubmit} className="login-form">
          {errorMsg && (
            <div className="login-error-alert">
              <span className="error-icon">⚠️</span>
              <p>{errorMsg}</p>
            </div>
          )}

          <div className="form-group">
            <label htmlFor="email">Email</label>
            <div className="input-wrapper">
              <span className="input-icon">✉️</span>
              <input
                id="email"
                type="email"
                placeholder="admin@fidee.site"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                disabled={isLoading}
              />
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="password">Mật khẩu</label>
            <div className="input-wrapper">
              <span className="input-icon">🔒</span>
              <input
                id="password"
                type="password"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                disabled={isLoading}
              />
            </div>
          </div>

          <button
            type="submit"
            className={`login-btn ${isLoading ? 'login-btn-loading' : ''}`}
            disabled={isLoading}
          >
            {isLoading ? (
              <span className="loading-spinner-wrapper">
                <span className="loading-spinner"></span>
                Đang kết nối...
              </span>
            ) : (
              'Đăng Nhập'
            )}
          </button>
        </form>
      </div>
    </div>
  );
}
