import { useEffect, useState } from 'react';
import { navigateToPath } from './navigation';
import {
  ActivityPage,
  AnalyticsPage,
  ContentPage,
  DashboardPage,
  ModerationDetailsPage,
  ModerationPage,
  PaymentsPage,
  PlacesPage,
  ReportsPage,
  ReviewsPage,
  SettingsPage,
  UsersPage,
} from './features/admin/AdminPages';

const NAV_ITEMS = [
  { icon: '📊', label: 'Dashboard', href: '/admin' },
  { icon: '🛡️', label: 'Moderation', href: '/admin/moderation' },
  { icon: '📍', label: 'Places', href: '/admin/places' },
  { icon: '📝', label: 'Reviews', href: '/admin/reviews' },
  { icon: '👥', label: 'Users', href: '/admin/users' },
  { icon: '📈', label: 'Analytics', href: '/admin/analytics' },
  { icon: '🧾', label: 'Reports', href: '/admin/reports' },
  { icon: '🕒', label: 'Activity Logs', href: '/admin/activity' },
  { icon: '🧩', label: 'Content', href: '/admin/content' },
  { icon: '💳', label: 'Payments', href: '/admin/payments' },
  { icon: '⚙️', label: 'Settings', href: '/admin/settings' },
];

function getRoute(pathname: string) {
  if (pathname === '/' || pathname === '/admin') {
    return { page: 'dashboard', detailId: null };
  }

  const moderationMatch = pathname.match(/^\/admin\/moderation\/([^/]+)$/);
  if (moderationMatch) {
    return { page: 'moderation-detail', detailId: moderationMatch[1] };
  }

  if (pathname.startsWith('/admin/moderation')) {
    return { page: 'moderation', detailId: null };
  }

  if (pathname.startsWith('/admin/places')) return { page: 'places', detailId: null };
  if (pathname.startsWith('/admin/reviews')) return { page: 'reviews', detailId: null };
  if (pathname.startsWith('/admin/users')) return { page: 'users', detailId: null };
  if (pathname.startsWith('/admin/analytics')) return { page: 'analytics', detailId: null };
  if (pathname.startsWith('/admin/reports')) return { page: 'reports', detailId: null };
  if (pathname.startsWith('/admin/activity')) return { page: 'activity', detailId: null };
  if (pathname.startsWith('/admin/content')) return { page: 'content', detailId: null };
  if (pathname.startsWith('/admin/payments')) return { page: 'payments', detailId: null };
  if (pathname.startsWith('/admin/settings')) return { page: 'settings', detailId: null };

  return { page: 'dashboard', detailId: null };
}

export default function App() {
  const [pathname, setPathname] = useState(() => window.location.pathname);

  useEffect(() => {
    const syncRoute = () => setPathname(window.location.pathname);

    window.addEventListener('popstate', syncRoute);
    syncRoute();

    return () => {
      window.removeEventListener('popstate', syncRoute);
    };
  }, []);

  const route = getRoute(pathname);

  const handleNavigate = (href: string) => {
    navigateToPath(href);
  };

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <span className="brand-icon">🗺️</span>
          <div>
            <h1 className="brand-text">MapVibe</h1>
            <span className="brand-badge">Admin</span>
          </div>
        </div>

        <nav className="sidebar-nav">
          {NAV_ITEMS.map((item) => {
            const isActive =
              (item.href === '/admin' && (route.page === 'dashboard' || route.page === 'dashboard')) ||
              (item.href !== '/admin' && pathname.startsWith(item.href));

            return (
              <button key={item.href} type="button" className={isActive ? 'nav-item nav-item-active' : 'nav-item'} onClick={() => handleNavigate(item.href)}>
                <span className="nav-icon">{item.icon}</span>
                <span>{item.label}</span>
              </button>
            );
          })}
        </nav>

        <div className="sidebar-footer">
          <div className="user-info">
            <div className="user-avatar">M</div>
            <div>
              <strong className="user-name">Minh Nguyen</strong>
              <p className="user-role">Admin</p>
            </div>
          </div>
        </div>
      </aside>

      <main className="main-content">
        {route.page === 'moderation-detail' && route.detailId ? <ModerationDetailsPage requestId={route.detailId} /> : null}
        {route.page === 'moderation' ? <ModerationPage /> : null}
        {route.page === 'dashboard' ? <DashboardPage /> : null}
        {route.page === 'places' ? <PlacesPage /> : null}
        {route.page === 'reviews' ? <ReviewsPage /> : null}
        {route.page === 'users' ? <UsersPage /> : null}
        {route.page === 'analytics' ? <AnalyticsPage /> : null}
        {route.page === 'reports' ? <ReportsPage /> : null}
        {route.page === 'activity' ? <ActivityPage /> : null}
        {route.page === 'content' ? <ContentPage /> : null}
        {route.page === 'payments' ? <PaymentsPage /> : null}
        {route.page === 'settings' ? <SettingsPage /> : null}
      </main>
    </div>
  );
}