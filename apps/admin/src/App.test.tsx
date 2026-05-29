import { beforeEach, describe, it, expect } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import App from './App';

beforeEach(() => {
  window.history.pushState({}, '', '/');
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

  it('opens the moderation detail page by id', async () => {
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: /moderation/i }));
    expect(await screen.findByText('Pending Candidates')).toBeInTheDocument();

    fireEvent.click(screen.getAllByRole('button', { name: 'View' })[0]);

    expect(await screen.findByRole('heading', { name: 'Rooftop Bar Saigon', level: 1 })).toBeInTheDocument();
    expect(window.location.pathname).toBe('/admin/moderation/cand-1001');
  });

  it('opens the users page from the sidebar', async () => {
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: /users/i }));

    expect(await screen.findByRole('heading', { name: 'Users', level: 1 })).toBeInTheDocument();
    expect(await screen.findByText('Total Users')).toBeInTheDocument();
  });
});