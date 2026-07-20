import { afterEach, beforeEach, describe, it, expect, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import App from './App';

vi.mock('./features/admin/adminApi', () => ({
  approveCandidate: vi.fn(),
  deletePlace: vi.fn(),
  fetchCandidateDetail: vi.fn().mockRejectedValue(new Error('Not found')),
  fetchModerationRequests: vi.fn().mockResolvedValue([]),
  fetchPlaces: vi.fn().mockResolvedValue([]),
  fetchUsers: vi.fn().mockResolvedValue([]),
  rejectCandidate: vi.fn(),
  savePlace: vi.fn(),
  updateUserData: vi.fn(),
}));

beforeEach(() => {
  window.history.pushState({}, '', '/');
});

afterEach(() => {
  vi.clearAllMocks();
});

describe('App', () => {
  it('renders the dashboard title', () => {
    render(<App />);
    expect(screen.getByRole('heading', { name: 'Dashboard' })).toBeInTheDocument();
  });

  it('renders the sidebar navigation', () => {
    render(<App />);
    expect(screen.getByText('Total Places')).toBeInTheDocument();
    expect(screen.getByText('Places')).toBeInTheDocument();
    expect(screen.getByText('Users')).toBeInTheDocument();
    expect(screen.getByText('Moderation')).toBeInTheDocument();
  });

  it('opens the moderation page from the sidebar', async () => {
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: /moderation/i }));

    expect(await screen.findByRole('heading', { name: 'Moderation', level: 1 })).toBeInTheDocument();
    expect(await screen.findByText('Pending Candidates')).toBeInTheDocument();
  });

  it('opens the moderation detail page by id without local fallback data', async () => {
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
    window.history.pushState({}, '', '/admin/moderation/cand-unknown');

    render(<App />);

    expect(await screen.findByText('Request not found')).toBeInTheDocument();
    expect(window.location.pathname).toBe('/admin/moderation/cand-unknown');
    consoleError.mockRestore();
  });

  it('opens the users page from the sidebar', async () => {
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: /users/i }));

    expect(await screen.findByRole('heading', { name: 'Users', level: 1 })).toBeInTheDocument();
    expect(await screen.findByText('Total Users')).toBeInTheDocument();
  });
});
