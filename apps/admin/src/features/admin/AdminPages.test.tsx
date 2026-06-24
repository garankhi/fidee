import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import { UsersPage } from './AdminPages';
import { fetchUsers } from './adminApi';

vi.mock('./adminApi', () => ({
  fetchUsers: vi.fn(),
  updateUserData: vi.fn(),
}));

const mockedFetchUsers = vi.mocked(fetchUsers);

describe('UsersPage', () => {
  afterEach(() => {
    vi.clearAllMocks();
    window.localStorage.setItem('admin_token', 'mock-admin-token-for-tests');
    window.history.pushState({}, '', '/admin/users');
  });

  it('redirects to login when the admin token is rejected', async () => {
    window.localStorage.setItem('admin_token', 'expired-token');
    window.history.pushState({}, '', '/admin/users');
    mockedFetchUsers.mockRejectedValue({ response: { status: 401 } });

    render(<UsersPage />);

    await waitFor(() => expect(window.location.pathname).toBe('/login'));
    expect(window.localStorage.getItem('admin_token')).toBeNull();
    expect(screen.queryByText(/Không thể kết nối tới API Backend/i)).not.toBeInTheDocument();
  });

  it('renders users returned by the API when username is missing', async () => {
    mockedFetchUsers.mockResolvedValue([
      {
        id: 'user-without-username',
        username: null,
        fullName: 'Missing Username',
        email: 'missing@example.com',
        phone: null,
        joinedDate: 'Jun 3, 2026',
        contributions: 0,
        status: 'active',
        license: 'Free',
        role: 'User',
      } as never,
    ]);

    render(<UsersPage />);

    expect(await screen.findAllByText('missing@example.com')).toHaveLength(2);
    expect(screen.getByText('Missing Username')).toBeInTheDocument();
    expect(screen.queryByText(/Không thể kết nối tới API Backend/i)).not.toBeInTheDocument();
  });
});
