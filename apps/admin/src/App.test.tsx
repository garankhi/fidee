import { beforeEach, describe, it, expect } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import App from './App';
import ModerationPage from './features/moderation/ModerationPage';

beforeEach(() => {
  window.history.pushState({}, '', '/');
});

describe('App', () => {
  it('renders the dashboard title', () => {
    render(<App />);
    expect(screen.getByRole('heading', { name: 'Dashboard', level: 2 })).toBeInTheDocument();
  });

  it('renders stat cards', () => {
    render(<App />);
    expect(screen.getByText('Total Places')).toBeInTheDocument();
    expect(screen.getByText('Active Users')).toBeInTheDocument();
  });

  it('renders navigation items', () => {
    render(<App />);
    expect(screen.getByText('Places')).toBeInTheDocument();
    expect(screen.getByText('Users')).toBeInTheDocument();
    expect(screen.getByText('Moderation')).toBeInTheDocument();
  });

  it('opens the moderation page from the sidebar', async () => {
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: /moderation/i }));

    expect(screen.getByRole('status')).toHaveTextContent('Loading moderation queue');
    expect(await screen.findByRole('heading', { name: 'Moderation', level: 2 })).toBeInTheDocument();
    expect(await screen.findByText('Pending Candidates')).toBeInTheDocument();
  });
});

describe('ModerationPage', () => {
  it('supports search, filter, and empty states', async () => {
    render(<ModerationPage />);

    expect(screen.getByRole('status')).toHaveTextContent('Loading moderation queue');
    expect(await screen.findByText('Rooftop Bar Saigon')).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Filter'), { target: { value: 'all' } });
    fireEvent.change(screen.getByLabelText('Status'), { target: { value: 'approved' } });

    expect(screen.getByText('Night Noodle Corner')).toBeInTheDocument();
    expect(screen.queryByText('Rooftop Bar Saigon')).not.toBeInTheDocument();

    fireEvent.change(screen.getByPlaceholderText('Search by title, source, or reason'), {
      target: { value: 'no matches here' },
    });

    expect(await screen.findByText('No requests found')).toBeInTheDocument();
  });

  it('shows an error state when the mock adapter fails', async () => {
    render(<ModerationPage />);

    fireEvent.click(screen.getByRole('button', { name: 'Simulate error' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Unable to load moderation queue.');
  });

  it('opens the detail page by id from the moderation list', async () => {
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: /moderation/i }));

    expect(await screen.findByText('Pending Candidates')).toBeInTheDocument();

    fireEvent.click(screen.getAllByRole('link', { name: 'View' })[0]);

    expect(await screen.findByRole('heading', { name: 'Rooftop Bar Saigon', level: 2 })).toBeInTheDocument();
    expect(window.location.pathname).toBe('/admin/moderation/cand-1001');
  });
});