import { describe, it, expect } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import App from './App';
import ModerationPage from './features/moderation/ModerationPage';

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
  it('supports search, filter, sort, and empty states', async () => {
    render(<ModerationPage />);

    expect(screen.getByRole('status')).toHaveTextContent('Loading moderation queue');
    expect(await screen.findByText('Rooftop Bar Saigon')).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Filter'), { target: { value: 'review' } });

    expect(screen.getByText('Spam review on Banh Mi Huynh Hoa')).toBeInTheDocument();
    expect(screen.getByText('Off-topic review for train station')).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Sort'), { target: { value: 'score' } });

    await waitFor(() => {
      const rows = screen.getAllByRole('row');
      expect(rows[1]).toHaveTextContent('Spam review on Banh Mi Huynh Hoa');
    });

    fireEvent.change(screen.getByPlaceholderText('Search by title, source, or reason'), {
      target: { value: 'no matches here' },
    });

    expect(await screen.findByText('No pending candidates')).toBeInTheDocument();
  });

  it('shows an error state when the mock adapter fails', async () => {
    render(<ModerationPage />);

    fireEvent.click(screen.getByRole('button', { name: 'Simulate error' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Unable to load moderation queue.');
  });
});