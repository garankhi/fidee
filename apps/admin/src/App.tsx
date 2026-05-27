import { useState } from 'react';
import ModerationPage from './features/moderation/ModerationPage';

const NAV_ITEMS = [
  { icon: '📊', label: 'Dashboard', id: 'dashboard' },
  { icon: '📍', label: 'Places', id: 'places' },
  { icon: '👥', label: 'Users', id: 'users' },
  { icon: '📝', label: 'Reviews', id: 'reviews' },
  { icon: '🛡️', label: 'Moderation', id: 'moderation' },
  { icon: '⚙️', label: 'Settings', id: 'settings' },
];

const STATS = [
  { label: 'Total Places', value: '1,247', change: '+12%', color: 'var(--accent-blue)' },
  { label: 'Active Users', value: '3,891', change: '+8%', color: 'var(--accent-purple)' },
  { label: 'Reviews Today', value: '142', change: '+23%', color: 'var(--accent-green)' },
  { label: 'Pending Moderation', value: '7', change: '-15%', color: 'var(--accent-orange)' },
];

export default function App() {
  const [activeNav, setActiveNav] = useState('dashboard');

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <span className="brand-icon">🗺️</span>
          <h1 className="brand-text">MapVibe</h1>
          <span className="brand-badge">Admin</span>
        </div>
        <nav className="sidebar-nav">
          {NAV_ITEMS.map((item) => (
            <button
              key={item.id}
              id={`nav-${item.id}`}
              className={`nav-item ${activeNav === item.id ? 'active' : ''}`}
              onClick={() => setActiveNav(item.id)}
            >
              <span className="nav-icon">{item.icon}</span>
              <span className="nav-label">{item.label}</span>
            </button>
          ))}
        </nav>
        <div className="sidebar-footer">
          <div className="user-info">
            <div className="user-avatar">M</div>
            <div>
              <div className="user-name">Minh Nguyen</div>
              <div className="user-role">Admin</div>
            </div>
          </div>
        </div>
      </aside>

      <main className="main">
        {activeNav === 'moderation' ? (
          <ModerationPage />
        ) : (
          <>
            <header className="main-header">
              <div>
                <h2 className="page-title">Dashboard</h2>
                <p className="page-subtitle">Welcome back, here's what's happening today.</p>
              </div>
              <div className="header-actions">
                <div className="search-box" id="search-box">
                  <span className="search-icon">🔍</span>
                  <input type="text" placeholder="Search..." className="search-input" />
                </div>
              </div>
            </header>

            <section className="stats-grid">
              {STATS.map((stat) => (
                <div key={stat.label} className="stat-card">
                  <div className="stat-header">
                    <span className="stat-label">{stat.label}</span>
                    <span className="stat-dot" style={{ backgroundColor: stat.color }} />
                  </div>
                  <div className="stat-value">{stat.value}</div>
                  <div className="stat-change">
                    <span className={stat.change.startsWith('+') ? 'positive' : 'negative'}>
                      {stat.change}
                    </span>
                    <span className="stat-period">vs last week</span>
                  </div>
                </div>
              ))}
            </section>

            <section className="content-area">
              <div className="card recent-activity">
                <h3 className="card-title">Recent Activity</h3>
                <div className="activity-list">
                  {[
                    { action: 'New place submitted', detail: 'Rooftop Bar Saigon', time: '2m ago', icon: '📍' },
                    { action: 'Review flagged', detail: 'Inappropriate content detected', time: '15m ago', icon: '🚩' },
                    { action: 'User registered', detail: 'user@example.com', time: '1h ago', icon: '👤' },
                    { action: 'AI summary refreshed', detail: 'Bánh Mì Huỳnh Hoa', time: '2h ago', icon: '🤖' },
                    { action: 'Badge awarded', detail: 'Gold Explorer — @foodie_sg', time: '3h ago', icon: '🏅' },
                  ].map((item, index) => (
                    <div key={index} className="activity-item">
                      <span className="activity-icon">{item.icon}</span>
                      <div className="activity-content">
                        <span className="activity-action">{item.action}</span>
                        <span className="activity-detail">{item.detail}</span>
                      </div>
                      <span className="activity-time">{item.time}</span>
                    </div>
                  ))}
                </div>
              </div>
              <div className="card quick-actions">
                <h3 className="card-title">Quick Actions</h3>
                <div className="actions-grid">
                  {[
                    { label: 'Add Place', icon: '➕', id: 'action-add-place' },
                    { label: 'View Reports', icon: '📋', id: 'action-reports' },
                    { label: 'Manage Badges', icon: '🏆', id: 'action-badges' },
                    { label: 'System Health', icon: '💚', id: 'action-health' },
                  ].map((action) => (
                    <button key={action.id} id={action.id} className="action-btn">
                      <span className="action-icon">{action.icon}</span>
                      <span className="action-label">{action.label}</span>
                    </button>
                  ))}
                </div>
              </div>
            </section>
          </>
        )}
      </main>
    </div>
  );
}