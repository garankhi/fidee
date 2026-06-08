import { useEffect, useMemo, useState } from 'react';
import { navigateToPath } from '../../navigation';
import { Skeleton } from 'boneyard-js/react';
import { fetchUsers, updateUserData } from './adminApi';
import {
  activityLogs,
  categoryPerformance,
  contentItems,
  getDashboardStats,
  getModerationStats,
  mockModerationRequests,
  mockPlaces,
  mockUsers,
  paymentRows,
  reportMetrics,
  settingsSections,
  userEngagementData,
  type ModerationRequest,
  type ModerationStatus,
  type User,
} from './adminData';

function cx(...classes: Array<string | false | null | undefined>) {
  return classes.filter(Boolean).join(' ');
}

function pageTone(status: string) {
  if (status === 'approved' || status === 'paid' || status === 'published') {
    return 'success';
  }

  if (status === 'pending' || status === 'needs review') {
    return 'warning';
  }

  if (status === 'rejected' || status === 'failed' || status === 'inactive') {
    return 'danger';
  }

  return 'neutral';
}

function getApiErrorStatus(error: unknown) {
  if (typeof error !== 'object' || error === null || !('response' in error)) {
    return null;
  }

  const response = (error as { response?: { status?: number } }).response;
  return typeof response?.status === 'number' ? response.status : null;
}

function isAuthRejected(error: unknown) {
  const status = getApiErrorStatus(error);
  return status === 401 || status === 403;
}

function redirectToLogin() {
  window.localStorage.removeItem('admin_token');
  navigateToPath('/login');
}

function normalizeUser(user: User): User {
  const username = user.username || user.email || user.fullName || 'unknown-user';

  return {
    ...user,
    username,
    fullName: user.fullName || username,
    email: user.email || '',
    phone: user.phone || '',
    contributions: user.contributions ?? 0,
    status: user.status || 'active',
    license: user.license || 'Free',
    role: user.role || 'User',
  };
}

function formatStatus(status: ModerationStatus) {
  return status.charAt(0).toUpperCase() + status.slice(1);
}

function renderStars(rating: number) {
  return Array.from({ length: 5 }, (_, index) => (
    <span key={index} className={index < Math.round(rating) ? 'star star-filled' : 'star'}>
      ★
    </span>
  ));
}

function PageHeader({ title, subtitle, action }: { title: string; subtitle: string; action?: React.ReactNode }) {
  return (
    <header className="page-header">
      <div>
        <h1 className="page-title">{title}</h1>
        <p className="page-subtitle">{subtitle}</p>
      </div>
      {action ? <div className="page-header-action">{action}</div> : null}
    </header>
  );
}

function StatCard({ label, value, delta, tone = 'neutral' }: { label: string; value: string | number; delta?: string; tone?: 'neutral' | 'success' | 'warning' | 'danger' }) {
  return (
    <article className="stat-card card">
      <div className="stat-card-label">{label}</div>
      <div className="stat-card-value">{value}</div>
      {delta ? <div className={cx('stat-card-delta', `tone-${tone}`)}>{delta} vs last week</div> : null}
    </article>
  );
}

function Badge({ children, tone = 'neutral' }: { children: React.ReactNode; tone?: 'neutral' | 'success' | 'warning' | 'danger' }) {
  return <span className={cx('badge', `badge-${tone}`)}>{children}</span>;
}

function ListPanel({ title, subtitle, children, action }: { title: string; subtitle?: string; children: React.ReactNode; action?: React.ReactNode }) {
  return (
    <section className="card panel-card">
      <div className="panel-head">
        <div>
          <h2 className="panel-title">{title}</h2>
          {subtitle ? <p className="panel-subtitle">{subtitle}</p> : null}
        </div>
        {action ? <div>{action}</div> : null}
      </div>
      {children}
    </section>
  );
}

function ChartBars({ data, valueKey, max = 400 }: { data: Array<Record<string, number | string>>; valueKey: string; max?: number }) {
  return (
    <div className="chart-bars">
      {data.map((item) => {
        const value = Number(item[valueKey]);
        return (
          <div key={String(item.date ?? item.category ?? item.label)} className="chart-bar-item">
            <div className="chart-bar-track">
              <div className="chart-bar-fill" style={{ height: `${Math.max(8, (value / max) * 100)}%` }} />
            </div>
            <span className="chart-bar-label">{String(item.date ?? item.category ?? item.label)}</span>
          </div>
        );
      })}
    </div>
  );
}

function SearchField({ value, onChange, placeholder }: { value: string; onChange: (value: string) => void; placeholder: string }) {
  return (
    <label className="field field-search">
      <span className="sr-only">Search</span>
      <input className="control-input" type="search" value={value} onChange={(event) => onChange(event.target.value)} placeholder={placeholder} />
    </label>
  );
}

export function DashboardPage() {
  const stats = getDashboardStats();
  const moderationStats = getModerationStats();

  return (
    <div className="page-stack">
      <PageHeader title="Dashboard" subtitle="Welcome back, here's what's happening today." />

      <section className="stats-grid stats-grid-4">
        <StatCard label="Total Places" value={stats.places} delta="12%" tone="success" />
        <StatCard label="Active Users" value={stats.activeUsers} delta="8%" tone="success" />
        <StatCard label="Reviews Today" value={stats.reviews} delta="23%" tone="warning" />
        <StatCard label="Pending Moderation" value={stats.pending} delta="15%" tone="danger" />
      </section>

      <section className="status-grid">
        <article className="card status-card status-card-warning">
          <div className="status-card-top">
            <span className="status-kicker">Pending</span>
            <strong>{moderationStats.pending}</strong>
          </div>
          <p>Awaiting moderation</p>
          <button type="button" className="text-link" onClick={() => navigateToPath('/admin/moderation')}>
            Review now
          </button>
        </article>
        <article className="card status-card status-card-success">
          <div className="status-card-top">
            <span className="status-kicker">Approved</span>
            <strong>{moderationStats.approved}</strong>
          </div>
          <p>Successfully published</p>
          <span className="status-footnote">Last 7 days</span>
        </article>
        <article className="card status-card status-card-danger">
          <div className="status-card-top">
            <span className="status-kicker">Rejected</span>
            <strong>{moderationStats.rejected}</strong>
          </div>
          <p>Declined submissions</p>
          <span className="status-footnote">Last 7 days</span>
        </article>
      </section>

      <section className="dashboard-grid">
        <ListPanel title="Activity Trend" subtitle="Last 7 days of submissions and reviews">
          <ChartBars data={userEngagementData} valueKey="visits" max={400} />
        </ListPanel>

        <ListPanel title="Quick Stats" subtitle="System overview">
          <div className="quick-stats">
            <div className="quick-stat-row">
              <span>Places this month</span>
              <strong>+42</strong>
            </div>
            <div className="quick-stat-row">
              <span>Reviews this month</span>
              <strong>+128</strong>
            </div>
            <div className="quick-stat-row">
              <span>Pending actions</span>
              <strong>{moderationStats.pending}</strong>
            </div>
          </div>
        </ListPanel>
      </section>

      <section className="dashboard-grid dashboard-grid-secondary">
        <ListPanel title="Recent Activity" subtitle="Latest platform events">
          <div className="activity-feed">
            {activityLogs.slice(0, 5).map((item) => (
              <article key={item.id} className="activity-item">
                <span className="activity-icon">{item.icon}</span>
                <div className="activity-copy">
                  <strong>{item.action}</strong>
                  <span>{item.target}</span>
                </div>
                <time>{item.timestamp}</time>
              </article>
            ))}
          </div>
        </ListPanel>

        <ListPanel title="Quick Actions" subtitle="Common tasks">
          <div className="actions-grid">
            {['Add Place', 'View Reports', 'Manage Badges', 'System Health'].map((action) => (
              <button key={action} type="button" className="action-card-btn">
                <span className="action-dot" />
                <span>{action}</span>
              </button>
            ))}
          </div>
        </ListPanel>
      </section>
    </div>
  );
}

export function ModerationPage() {
  const [search, setSearch] = useState('');
  const [filterType, setFilterType] = useState<'all-pending' | 'all'>('all-pending');
  const [filterStatus, setFilterStatus] = useState<ModerationStatus | 'All'>('All');
  const [requests, setRequests] = useState<ModerationRequest[]>(mockModerationRequests);

  const stats = useMemo(() => {
    return {
      total: requests.length,
      pending: requests.filter((request) => request.status === 'pending').length,
      approved: requests.filter((request) => request.status === 'approved').length,
    };
  }, [requests]);

  const filteredRequests = useMemo(() => {
    return requests.filter((request) => {
      const query = search.trim().toLowerCase();
      const matchesSearch =
        query === '' ||
        [request.name, request.summary, request.source, request.submittedBy, request.placeDetails.name].join(' ').toLowerCase().includes(query);

      const matchesType = filterType === 'all' || request.status === 'pending';
      const matchesStatus = filterStatus === 'All' || request.status === filterStatus;

      return matchesSearch && matchesType && matchesStatus;
    });
  }, [filterStatus, filterType, requests, search]);

  const handleDecision = (requestId: string, status: ModerationStatus) => {
    setRequests((current) => current.map((request) => (request.id === requestId ? { ...request, status } : request)));
  };

  return (
    <div className="page-stack">
      <PageHeader
        title="Moderation"
        subtitle="Review pending candidates without waiting for backend data."
        action={<span className="queue-pill">{filteredRequests.length} items</span>}
      />

      <section className="stats-grid stats-grid-3">
        <StatCard label="Total" value={stats.total} />
        <StatCard label="Pending" value={stats.pending} tone="warning" />
        <StatCard label="Approved" value={stats.approved} tone="success" />
      </section>

      <section className="card toolbar-card">
        <SearchField value={search} onChange={setSearch} placeholder="Search by title, source, or reason" />
        <label className="field">
          <span className="field-label">Filter</span>
          <select className="control-input" value={filterType} onChange={(event) => setFilterType(event.target.value as 'all-pending' | 'all')}>
            <option value="all-pending">All pending</option>
            <option value="all">All</option>
          </select>
        </label>
        <label className="field">
          <span className="field-label">Status</span>
          <select className="control-input" value={filterStatus} onChange={(event) => setFilterStatus(event.target.value as ModerationStatus | 'All')}>
            <option value="All">All</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
          </select>
        </label>
      </section>

      <ListPanel title="Pending Candidates" subtitle={`${filteredRequests.length} items`}>
        <div className="table-scroll">
          <table className="data-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Submitted</th>
                <th>Submitted By</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredRequests.map((request) => (
                <tr key={request.id}>
                  <td>
                    <div className="candidate-cell">
                      <strong>{request.name}</strong>
                      <span>{request.source}</span>
                    </div>
                  </td>
                  <td>{request.submittedAt}</td>
                  <td>{request.submittedBy}</td>
                  <td>
                    <Badge tone={pageTone(request.status)}>{formatStatus(request.status)}</Badge>
                  </td>
                  <td>
                    <div className="table-actions">
                      <button type="button" className="approve-btn" onClick={() => handleDecision(request.id, 'approved')}>
                        Approve
                      </button>
                      <button type="button" className="reject-btn" onClick={() => handleDecision(request.id, 'rejected')}>
                        Reject
                      </button>
                      <button type="button" className="secondary-btn" onClick={() => navigateToPath(`/admin/moderation/${request.id}`)}>
                        View
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </ListPanel>
    </div>
  );
}

export function ModerationDetailsPage({ requestId }: { requestId: string }) {
  const [actionTaken, setActionTaken] = useState<ModerationStatus | null>(null);
  const request = mockModerationRequests.find((item) => item.id === requestId);

  if (!request) {
    return (
      <div className="page-stack">
        <ListPanel title="Request not found" subtitle="The moderation request you opened no longer exists.">
          <button type="button" className="primary-btn" onClick={() => navigateToPath('/admin/moderation')}>
            Back to Moderation
          </button>
        </ListPanel>
      </div>
    );
  }

  const handleApprove = () => {
    setActionTaken('approved');
    window.setTimeout(() => navigateToPath('/admin/moderation'), 1200);
  };

  const handleReject = () => {
    setActionTaken('rejected');
    window.setTimeout(() => navigateToPath('/admin/moderation'), 1200);
  };

  return (
    <div className="page-stack moderation-details-page">
      <PageHeader
        title={request.placeDetails.name}
        subtitle="Review submission details"
        action={<button type="button" className="secondary-btn" onClick={() => navigateToPath('/admin/moderation')}>Close</button>}
      />

      {actionTaken ? (
        <div className={cx('card', 'state-card', actionTaken === 'approved' ? 'state-card-success' : 'state-card-danger')}>
          {actionTaken === 'approved' ? 'Request approved successfully' : 'Request rejected successfully'}
        </div>
      ) : null}

      <div className="details-layout">
        <div className="details-main">
          <section className="card details-card">
            <h2 className="panel-title">Submission Information</h2>
            <div className="details-grid">
              <div>
                <span className="detail-label">Submitted By</span>
                <strong>{request.submittedBy}</strong>
              </div>
              <div>
                <span className="detail-label">Submitted</span>
                <strong>{request.submittedAt}</strong>
              </div>
              <div>
                <span className="detail-label">Status</span>
                <Badge tone={pageTone(request.status)}>{request.status}</Badge>
              </div>
              <div>
                <span className="detail-label">Source</span>
                <strong>{request.source}</strong>
              </div>
            </div>
            <div className="detail-block">
              <span className="detail-label">Summary</span>
              <p>{request.summary}</p>
            </div>
          </section>

          <section className="card details-card">
            <h2 className="panel-title">Place Details</h2>
            <div className="detail-block">
              <span className="detail-label">Name</span>
              <strong className="detail-title">{request.placeDetails.name}</strong>
            </div>
            <div className="details-grid details-grid-2">
              <div>
                <span className="detail-label">Address</span>
                <p>{request.placeDetails.address}</p>
              </div>
              <div>
                <span className="detail-label">Phone</span>
                <p>{request.placeDetails.phone || '—'}</p>
              </div>
            </div>
            <div className="detail-block">
              <span className="detail-label">Description</span>
              <p>{request.placeDetails.description}</p>
            </div>
            <div className="detail-block">
              <span className="detail-label">Amenities</span>
              <div className="amenities-list">
                {request.placeDetails.amenities.map((amenity) => (
                  <span key={amenity} className="amenity-pill">
                    {amenity}
                  </span>
                ))}
              </div>
            </div>
          </section>

          {request.posterReview ? (
            <section className="card details-card">
              <h2 className="panel-title">Poster Review</h2>
              <div className="rating-stars">{renderStars(request.posterReview.rating)}</div>
              <p>{request.posterReview.text}</p>
            </section>
          ) : null}

          <section className="card details-card">
            <h2 className="panel-title">Media</h2>
            <div className="media-groups">
              {request.images?.menu ? (
                <div className="gallery">
                  <div className="gallery-title">Menu</div>
                  <div className="images-row">
                    {request.images.menu.map((src) => (
                      <img key={src} src={src} alt="menu" />
                    ))}
                  </div>
                </div>
              ) : null}
              {request.images?.space ? (
                <div className="gallery">
                  <div className="gallery-title">Space</div>
                  <div className="images-row">
                    {request.images.space.map((src) => (
                      <img key={src} src={src} alt="space" />
                    ))}
                  </div>
                </div>
              ) : null}
              {request.images?.dishes ? (
                <div className="gallery">
                  <div className="gallery-title">Dishes</div>
                  <div className="images-row">
                    {request.images.dishes.map((src) => (
                      <img key={src} src={src} alt="dish" />
                    ))}
                  </div>
                </div>
              ) : null}
            </div>
          </section>
        </div>

        <aside className="details-side">
          <section className="card details-card sticky-card">
            <h2 className="panel-title">Actions</h2>
            <div className="details-actions">
              <button type="button" className="approve-btn" onClick={handleApprove} disabled={actionTaken !== null}>
                Approve
              </button>
              <button type="button" className="reject-btn" onClick={handleReject} disabled={actionTaken !== null}>
                Reject
              </button>
              <button type="button" className="secondary-btn" onClick={() => navigateToPath('/admin/moderation')}>
                Back
              </button>
            </div>
          </section>

          <section className="card details-card">
            <h2 className="panel-title">Submission Meta</h2>
            <div className="detail-block">
              <span className="detail-label">Type</span>
              <strong>{request.type === 'up-spots' ? 'New Place' : 'Review'}</strong>
            </div>
            <div className="detail-block">
              <span className="detail-label">Submitted By</span>
              <strong>{request.submittedBy}</strong>
            </div>
            <div className="detail-block">
              <span className="detail-label">Submitted At</span>
              <strong>{request.submittedAt}</strong>
            </div>
          </section>
        </aside>
      </div>
    </div>
  );
}

function UserSkeletonRow() {
  return (
    <article className="user-grid-row skeleton-pulse" style={{ pointerEvents: 'none' }}>
      <div className="list-main">
        <div className="avatar" style={{ background: 'var(--surface-3)', boxShadow: 'none' }} />
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', width: '100px' }}>
          <div style={{ height: '14px', background: 'var(--surface-3)', borderRadius: '4px', width: '80px' }} />
          <div style={{ height: '10px', background: 'var(--surface-3)', borderRadius: '4px', width: '120px' }} />
        </div>
      </div>
      <div style={{ height: '14px', background: 'var(--surface-3)', borderRadius: '4px', width: '100px' }} />
      <div style={{ height: '22px', background: 'var(--surface-3)', borderRadius: '12px', width: '60px' }} />
      <div style={{ height: '22px', background: 'var(--surface-3)', borderRadius: '12px', width: '80px' }} />
      <div style={{ height: '14px', background: 'var(--surface-3)', borderRadius: '4px', width: '30px' }} />
      <div style={{ height: '22px', background: 'var(--surface-3)', borderRadius: '12px', width: '60px' }} />
      <div style={{ textAlign: 'right' }}>
        <div style={{ height: '34px', background: 'var(--surface-3)', borderRadius: '12px', width: '60px', marginLeft: 'auto' }} />
      </div>
    </article>
  );
}

function UserSkeletonList() {
  return (
    <div className="list-stack users-list">
      {/* Header Row */}
      <div className="user-grid-row" style={{ background: 'transparent', border: 0, fontWeight: 700, color: 'var(--muted)', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.08em', paddingBottom: '4px', paddingTop: '4px', boxShadow: 'none' }}>
        <span>User Info</span>
        <span>Full Name</span>
        <span>Role</span>
        <span>License</span>
        <span>Contributions</span>
        <span>Status</span>
        <span style={{ textAlign: 'right' }}>Actions</span>
      </div>
      <UserSkeletonRow />
      <UserSkeletonRow />
      <UserSkeletonRow />
      <UserSkeletonRow />
      <UserSkeletonRow />
    </div>
  );
}

export function UsersPage() {
  const [users, setUsers] = useState<User[]>(mockUsers);
  const [isLoading, setIsLoading] = useState(true);
  const [isOfflineMode, setIsOfflineMode] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState<'all' | 'active' | 'inactive'>('all');
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [toast, setToast] = useState<{ title: string; message: string } | null>(null);

  useEffect(() => {
    let active = true;
    async function loadUsers() {
      setIsLoading(true);
      try {
        const realUsers = await fetchUsers();
        if (active) {
          setUsers(realUsers.map(normalizeUser));
          setIsOfflineMode(false);
        }
      } catch (error) {
        if (isAuthRejected(error)) {
          redirectToLogin();
          return;
        }

        console.warn('API error, falling back to mock users:', error);
        if (active) {
          setUsers(mockUsers);
          setIsOfflineMode(true);
        }
      } finally {
        if (active) {
          setIsLoading(false);
        }
      }
    }
    loadUsers();
    return () => {
      active = false;
    };
  }, []);

  const filteredUsers = useMemo(() => {
    return users.filter((user) => {
      const query = search.trim().toLowerCase();
      const matchesSearch =
        query === '' ||
        user.username.toLowerCase().includes(query) ||
        user.email.toLowerCase().includes(query) ||
        user.fullName.toLowerCase().includes(query) ||
        user.phone.toLowerCase().includes(query);
      const matchesStatus = filterStatus === 'all' || user.status === filterStatus;
      return matchesSearch && matchesStatus;
    });
  }, [filterStatus, search, users]);

  const activeCount = useMemo(() => users.filter((u) => u.status === 'active').length, [users]);
  const totalContributions = useMemo(() => users.reduce((sum, u) => sum + u.contributions, 0), [users]);

  return (
    <div className="page-stack">
      <PageHeader title="Users" subtitle="Manage user accounts and contributions" />
      <section className="stats-grid stats-grid-3">
        <StatCard label="Total Users" value={users.length} />
        <StatCard label="Active" value={activeCount} tone="success" />
        <StatCard label="Total Contributions" value={totalContributions} />
      </section>

      {isOfflineMode && (
        <div className="offline-banner">
          <span>⚠️</span>
          <span>Không thể kết nối tới API Backend. Hệ thống đang chạy ở chế độ ngoại tuyến (Offline Mock Data).</span>
        </div>
      )}

      <section className="card toolbar-card">
        <SearchField value={search} onChange={setSearch} placeholder="Search by username, email, name, or phone..." />
        <label className="field">
          <span className="field-label">Status</span>
          <select className="control-input" value={filterStatus} onChange={(event) => setFilterStatus(event.target.value as 'all' | 'active' | 'inactive')}>
            <option value="all">All users</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
          </select>
        </label>
      </section>

      <ListPanel title="Users" subtitle={`${filteredUsers.length} users`}>
        <Skeleton name="users-list" loading={isLoading} fallback={<UserSkeletonList />}>
          <div className="list-stack users-list">
            {/* Header Row */}
            <div className="user-grid-row" style={{ background: 'transparent', border: 0, fontWeight: 700, color: 'var(--muted)', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.08em', paddingBottom: '4px', paddingTop: '4px', boxShadow: 'none' }}>
              <span>User Info</span>
              <span>Full Name</span>
              <span>Role</span>
              <span>License</span>
              <span>Contributions</span>
              <span>Status</span>
              <span style={{ textAlign: 'right' }}>Actions</span>
            </div>

            {filteredUsers.map((user) => {
              let avatarClass = 'avatar-user';
              if (user.role === 'Admin') avatarClass = 'avatar-admin';
              else if (user.role === 'Moderator') avatarClass = 'avatar-moderator';

              return (
                <article key={user.id} className="user-grid-row">
                  <div className="list-main">
                    <div className={`avatar ${avatarClass}`}>{user.username.charAt(0).toUpperCase()}</div>
                    <div>
                      <strong style={{ fontSize: '15px' }}>{user.username}</strong>
                      <span>{user.email}</span>
                    </div>
                  </div>
                  <div style={{ fontSize: '14px', fontWeight: 600 }}>{user.fullName}</div>
                  <div>
                    <Badge tone={user.role === 'Admin' ? 'danger' : user.role === 'Moderator' ? 'warning' : 'neutral'}>
                      {user.role}
                    </Badge>
                  </div>
                  <div>
                    <span className={`badge badge-${user.license.toLowerCase()}`}>{user.license}</span>
                  </div>
                  <div style={{ color: 'var(--muted)', fontWeight: 600, fontSize: '14px' }}>{user.contributions}</div>
                  <div>
                    <Badge tone={user.status === 'active' ? 'success' : 'neutral'}>{user.status === 'active' ? 'Active' : 'Inactive'}</Badge>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <button type="button" className="secondary-btn" style={{ padding: '8px 12px', fontSize: '13px' }} onClick={() => setEditingUser(user)}>
                      ✏️ Edit
                    </button>
                  </div>
                </article>
              );
            })}
          </div>
        </Skeleton>
      </ListPanel>

      {/* Edit User Modal */}
      {editingUser && (
        <div className="modal-overlay" onClick={() => (isSaving ? null : setEditingUser(null))}>
          <div className="modal-container" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Edit User Profile</h2>
              <button type="button" className="modal-close-btn" onClick={() => setEditingUser(null)} disabled={isSaving}>
                ✕
              </button>
            </div>
            
            <form onSubmit={async (e) => {
              e.preventDefault();
              setIsSaving(true);
              try {
                if (isOfflineMode) {
                  setUsers((prev) => prev.map((u) => u.id === editingUser.id ? editingUser : u));
                  setToast({
                    title: 'Cập nhật thành công (Ngoại tuyến)',
                    message: `Đã cập nhật giả lập cho tài khoản ${editingUser.username}.`
                    });
                  } else {
                    const updated = normalizeUser(await updateUserData(editingUser.id, editingUser));
                    setUsers((prev) => prev.map((u) => u.id === updated.id ? updated : u));
                    setToast({
                    title: 'Cập nhật thành công (API thực)',
                    message: `Đã lưu thông tin người dùng ${editingUser.username} lên hệ thống thực.`
                  });
                }
                } catch (error) {
                  if (isAuthRejected(error)) {
                    redirectToLogin();
                    return;
                  }

                  console.error('Update user error:', error);
                  setToast({
                    title: 'Lỗi cập nhật API',
                    message: error instanceof Error ? error.message : 'Không thể kết nối máy chủ.'
                });
              } finally {
                setIsSaving(false);
                setEditingUser(null);
                setTimeout(() => setToast(null), 3000);
              }
            }}>
              <div className="form-stack">
                <div className="form-row">
                  <label className="field">
                    <span className="field-label">Username</span>
                    <input
                      className="control-input"
                      type="text"
                      value={editingUser.username}
                      disabled
                      style={{ opacity: 0.6, cursor: 'not-allowed' }}
                    />
                  </label>
                  <label className="field">
                    <span className="field-label">Email</span>
                    <input
                      className="control-input"
                      type="email"
                      required
                      value={editingUser.email}
                      onChange={(e) => setEditingUser({ ...editingUser, email: e.target.value })}
                    />
                  </label>
                </div>

                <div className="form-row">
                  <label className="field">
                    <span className="field-label">Full Name</span>
                    <input
                      className="control-input"
                      type="text"
                      required
                      value={editingUser.fullName}
                      onChange={(e) => setEditingUser({ ...editingUser, fullName: e.target.value })}
                    />
                  </label>
                  <label className="field">
                    <span className="field-label">Phone</span>
                    <input
                      className="control-input"
                      type="text"
                      required
                      value={editingUser.phone}
                      onChange={(e) => setEditingUser({ ...editingUser, phone: e.target.value })}
                    />
                  </label>
                </div>

                <div className="form-row">
                  <label className="field">
                    <span className="field-label">Role</span>
                    <select
                      className="control-input"
                      value={editingUser.role}
                      onChange={(e) => setEditingUser({ ...editingUser, role: e.target.value as User['role'] })}
                    >
                      <option value="User">User</option>
                      <option value="Moderator">Moderator</option>
                      <option value="Admin">Admin</option>
                    </select>
                  </label>
                  <label className="field">
                    <span className="field-label">License Plan</span>
                    <select
                      className="control-input"
                      value={editingUser.license}
                      onChange={(e) => setEditingUser({ ...editingUser, license: e.target.value as User['license'] })}
                    >
                      <option value="Free">Free</option>
                      <option value="Basic">Basic</option>
                      <option value="Pro">Pro</option>
                      <option value="Enterprise">Enterprise</option>
                    </select>
                  </label>
                </div>

                <div className="form-row">
                  <label className="field">
                    <span className="field-label">Status</span>
                    <select
                      className="control-input"
                      value={editingUser.status}
                      onChange={(e) => setEditingUser({ ...editingUser, status: e.target.value as User['status'] })}
                    >
                      <option value="active">Active</option>
                      <option value="inactive">Inactive</option>
                    </select>
                  </label>
                  <label className="field">
                    <span className="field-label">Contributions</span>
                    <input
                      className="control-input"
                      type="number"
                      min="0"
                      value={editingUser.contributions}
                      onChange={(e) => setEditingUser({ ...editingUser, contributions: parseInt(e.target.value) || 0 })}
                    />
                  </label>
                </div>
              </div>

              <div className="form-actions">
                <button type="button" className="secondary-btn" onClick={() => setEditingUser(null)} disabled={isSaving}>
                  Cancel
                </button>
                <button type="submit" className="primary-btn" disabled={isSaving}>
                  {isSaving ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Success Toast */}
      {toast && (
        <div className="toast-container">
          <div className="toast-card toast-success">
            <span className="toast-icon">✨</span>
            <div className="toast-content">
              <div className="toast-title">{toast.title}</div>
              <div className="toast-message">{toast.message}</div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export function PlacesPage() {
  const [search, setSearch] = useState('');

  const filteredPlaces = useMemo(() => {
    const query = search.trim().toLowerCase();
    return mockPlaces.filter((place) => query === '' || [place.name, place.address, place.description].join(' ').toLowerCase().includes(query));
  }, [search]);

  const totalReviews = mockPlaces.reduce((sum, place) => sum + place.reviews, 0);
  const avgRating = (mockPlaces.reduce((sum, place) => sum + place.rating, 0) / mockPlaces.length).toFixed(1);

  return (
    <div className="page-stack">
      <PageHeader title="Places" subtitle="Manage all restaurant and venue listings" action={<button className="primary-btn" type="button">Add Place</button>} />
      <section className="stats-grid stats-grid-3">
        <StatCard label="Total Places" value={mockPlaces.length} />
        <StatCard label="Total Reviews" value={totalReviews} />
        <StatCard label="Avg Rating" value={`${avgRating}/5`} tone="success" />
      </section>

      <section className="card toolbar-card">
        <SearchField value={search} onChange={setSearch} placeholder="Search places by name, address, or description..." />
      </section>

      <section className="cards-grid">
        {filteredPlaces.map((place) => (
          <article key={place.id} className="card place-card">
            <div className="place-card-head">
              <div>
                <h2>{place.name}</h2>
                <div className="rating-row">{renderStars(place.rating)} <span>{place.rating.toFixed(1)}/5</span></div>
              </div>
              <div className="card-actions-inline">
                <button type="button" className="icon-btn">✏️</button>
                <button type="button" className="icon-btn">🗑️</button>
              </div>
            </div>
            <div className="place-info-row">📍 {place.address}</div>
            <p>{place.description}</p>
            <div className="place-footer">
              <div className="mini-meta">💬 {place.reviews} reviews</div>
              <div className="pill-list">
                {place.amenities.slice(0, 3).map((amenity) => (
                  <span key={amenity} className="amenity-pill">
                    {amenity}
                  </span>
                ))}
              </div>
            </div>
          </article>
        ))}
      </section>
    </div>
  );
}

export function ReviewsPage() {
  const [search, setSearch] = useState('');
  const [filterRating, setFilterRating] = useState<'all' | '5' | '4' | '3' | '2' | '1'>('all');

  const reviews = useMemo(() => {
    return mockModerationRequests
      .filter((request) => request.posterReview && request.type === 'review')
      .map((request) => ({
        id: request.id,
        placeName: request.placeDetails.name,
        author: request.submittedBy,
        rating: request.posterReview?.rating ?? 0,
        content: request.posterReview?.text ?? '',
        date: request.submittedAt,
      }))
      .filter((review) => {
        const query = search.trim().toLowerCase();
        const matchesSearch =
          query === '' || [review.placeName, review.author, review.content].join(' ').toLowerCase().includes(query);
        const matchesRating = filterRating === 'all' || review.rating === Number(filterRating);
        return matchesSearch && matchesRating;
      });
  }, [filterRating, search]);

  const avgRating = reviews.length === 0 ? 0 : reviews.reduce((sum, review) => sum + review.rating, 0) / reviews.length;

  return (
    <div className="page-stack">
      <PageHeader title="Reviews" subtitle="Manage and moderate user reviews" />
      <section className="stats-grid stats-grid-3">
        <StatCard label="Total Reviews" value={reviews.length} />
        <StatCard label="Avg Rating" value={`${avgRating.toFixed(1)}/5`} tone="warning" />
        <StatCard label="Flagged" value={Math.max(1, Math.floor(reviews.length * 0.15))} tone="danger" />
      </section>

      <section className="card toolbar-card">
        <SearchField value={search} onChange={setSearch} placeholder="Search by place, author, or content..." />
        <label className="field">
          <span className="field-label">Rating</span>
          <select className="control-input" value={filterRating} onChange={(event) => setFilterRating(event.target.value as 'all' | '5' | '4' | '3' | '2' | '1')}>
            <option value="all">All ratings</option>
            <option value="5">5 stars</option>
            <option value="4">4 stars</option>
            <option value="3">3 stars</option>
            <option value="2">2 stars</option>
            <option value="1">1 star</option>
          </select>
        </label>
      </section>

      <ListPanel title="Reviews" subtitle={`${reviews.length} reviews`}>
        <div className="list-stack">
          {reviews.map((review) => (
            <article key={review.id} className="review-card">
              <div className="review-head">
                <div>
                  <strong>{review.placeName}</strong>
                  <div className="rating-row compact">{renderStars(review.rating)} <span>{review.rating}/5</span></div>
                </div>
                <div className="card-actions-inline">
                  <button type="button" className="icon-btn">👁️</button>
                  <button type="button" className="icon-btn">🚩</button>
                  <button type="button" className="icon-btn">🗑️</button>
                </div>
              </div>
              <div className="review-meta">by {review.author} • {review.date}</div>
              <p>{review.content}</p>
            </article>
          ))}
        </div>
      </ListPanel>
    </div>
  );
}

export function AnalyticsPage() {
  return (
    <div className="page-stack">
      <PageHeader title="Analytics" subtitle="Performance charts and operational trends" action={<button className="secondary-btn" type="button">Export</button>} />

      <section className="stats-grid stats-grid-4">
        {reportMetrics.map((metric) => (
          <StatCard key={metric.label} label={metric.label} value={metric.value} delta={metric.trend} tone={metric.tone === 'danger' ? 'danger' : metric.tone === 'warning' ? 'warning' : 'success'} />
        ))}
      </section>

      <section className="dashboard-grid">
        <ListPanel title="User Engagement" subtitle="Weekly activity overview">
          <ChartBars data={userEngagementData} valueKey="visits" max={400} />
        </ListPanel>

        <ListPanel title="New Signups" subtitle="Weekly registration trend">
          <ChartBars data={userEngagementData} valueKey="signups" max={60} />
        </ListPanel>
      </section>

      <ListPanel title="Category Performance" subtitle="Restaurant category breakdown">
        <div className="table-scroll">
          <table className="data-table">
            <thead>
              <tr>
                <th>Category</th>
                <th>Places</th>
                <th>Views</th>
                <th>Avg Rating</th>
                <th>Growth</th>
              </tr>
            </thead>
            <tbody>
              {categoryPerformance.map((category) => (
                <tr key={category.category}>
                  <td>{category.category}</td>
                  <td>{category.places}</td>
                  <td>{category.views.toLocaleString()}</td>
                  <td>{category.avgRating.toFixed(1)} ⭐</td>
                  <td className="text-positive">+12%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </ListPanel>
    </div>
  );
}

export function ActivityPage() {
  const [search, setSearch] = useState('');
  const [filterType, setFilterType] = useState<'all' | string>('all');

  const logs = useMemo(() => {
    return activityLogs.filter((log) => {
      const query = search.trim().toLowerCase();
      const matchesSearch = query === '' || [log.user, log.action, log.target].join(' ').toLowerCase().includes(query);
      const matchesType = filterType === 'all' || log.type === filterType;
      return matchesSearch && matchesType;
    });
  }, [filterType, search]);

  return (
    <div className="page-stack">
      <PageHeader title="Activity Logs" subtitle="Track all user and system activities on the platform." />
      <section className="stats-grid stats-grid-3">
        <StatCard label="Total Activities" value="2,847" />
        <StatCard label="Today" value="284" tone="success" />
        <StatCard label="This Week" value="1,842" tone="success" />
      </section>

      <section className="card toolbar-card">
        <SearchField value={search} onChange={setSearch} placeholder="Search by user, action, or target..." />
        <label className="field">
          <span className="field-label">Type</span>
          <select className="control-input" value={filterType} onChange={(event) => setFilterType(event.target.value)}>
            <option value="all">All Activity Types</option>
            <option value="create">New Submissions</option>
            <option value="review">Reviews</option>
            <option value="approve">Approvals</option>
            <option value="reject">Rejections</option>
            <option value="flag">Flags</option>
            <option value="edit">Edits</option>
            <option value="delete">Deletions</option>
          </select>
        </label>
      </section>

      <ListPanel title="Recent Activities" subtitle={`${logs.length} activities`}>
        <div className="list-stack">
          {logs.map((log) => (
            <article key={log.id} className="activity-log">
              <span className="activity-icon activity-icon-square">{log.icon}</span>
              <div className="activity-copy">
                <strong>{log.action}</strong>
                <span>by {log.user} • {log.target}</span>
              </div>
              <time>{log.timestamp}</time>
            </article>
          ))}
        </div>
      </ListPanel>
    </div>
  );
}

export function ReportsPage() {
  const [dateRange, setDateRange] = useState('week');

  return (
    <div className="page-stack">
      <PageHeader title="Reports & Insights" subtitle="Detailed analytics and performance reports." action={<button className="secondary-btn" type="button">Export Report</button>} />

      <section className="card toolbar-card toolbar-inline">
        <span className="field-label">View Report:</span>
        <div className="segmented-control">
          {['day', 'week', 'month', 'year'].map((range) => (
            <button key={range} type="button" className={cx('segment-btn', dateRange === range && 'segment-btn-active')} onClick={() => setDateRange(range)}>
              {range.charAt(0).toUpperCase() + range.slice(1)}
            </button>
          ))}
        </div>
      </section>

      <section className="stats-grid stats-grid-4">
        {reportMetrics.map((metric) => (
          <StatCard key={metric.label} label={metric.label} value={metric.value} delta={metric.trend} tone={metric.tone === 'danger' ? 'danger' : metric.tone === 'warning' ? 'warning' : 'success'} />
        ))}
      </section>

      <section className="dashboard-grid">
        <ListPanel title="User Engagement" subtitle="Weekly activity overview">
          <ChartBars data={userEngagementData} valueKey="visits" max={400} />
        </ListPanel>
        <ListPanel title="Signups Trend" subtitle="Weekly registration trend">
          <ChartBars data={userEngagementData} valueKey="signups" max={60} />
        </ListPanel>
      </section>

      <ListPanel title="Key Insights" subtitle="What the team should focus on next">
        <div className="insights-grid">
          <div>
            <strong>Highest Engagement</strong>
            <p>Vietnamese restaurants have the highest user engagement with 12.4K views.</p>
          </div>
          <div>
            <strong>User Growth</strong>
            <p>Weekly signups increased by 8%, with peak on Saturday.</p>
          </div>
          <div>
            <strong>Moderation Priority</strong>
            <p>75% report resolution rate is good, but aim for 90% within 24 hours.</p>
          </div>
        </div>
      </ListPanel>
    </div>
  );
}

export function ContentPage() {
  const [search, setSearch] = useState('');

  const items = useMemo(() => {
    const query = search.trim().toLowerCase();
    return contentItems.filter((item) => query === '' || [item.title, item.type, item.category, item.status, String(item.views), item.createdAt].join(' ').toLowerCase().includes(query));
  }, [search]);

  return (
    <div className="page-stack">
      <PageHeader title="Content" subtitle="Manage featured pages, copy, and content blocks" />
      <section className="stats-grid stats-grid-3">
        <StatCard label="Total Content" value={contentItems.length} />
        <StatCard label="Published" value={contentItems.filter((item) => item.status === 'published').length} tone="success" />
        <StatCard label="Needs Review" value={contentItems.filter((item) => item.status === 'needs review').length} tone="warning" />
      </section>

      <section className="card toolbar-card">
        <SearchField value={search} onChange={setSearch} placeholder="Search by title, owner, or category..." />
      </section>

      <ListPanel title="Content Items" subtitle={`${items.length} entries`}>
        <div className="table-scroll content-table-shell">
          <div className="content-table">
            <div className="content-table-head">
              <span>Title</span>
              <span>Type</span>
              <span>Status</span>
              <span>Views</span>
              <span>Created</span>
              <span>Actions</span>
            </div>
          {items.map((item) => (
              <article key={item.id} className="content-row">
                <div className="content-title-cell">
                  <strong>{item.title}</strong>
                  <span>{item.category}</span>
                </div>
                <div>
                  <Badge tone="neutral">{item.type}</Badge>
                </div>
                <div>
                  <Badge tone={pageTone(item.status)}>{item.status === 'needs review' ? 'Review' : item.status}</Badge>
                </div>
                <div className="content-metric">{item.views.toLocaleString()}</div>
                <div className="content-date">📅 {item.createdAt}</div>
                <div className="content-actions">
                  <button type="button" className="icon-btn">👁️</button>
                  <button type="button" className="icon-btn">✏️</button>
                  <button type="button" className="icon-btn">🗑️</button>
                </div>
              </article>
          ))}
          </div>
        </div>
      </ListPanel>
    </div>
  );
}

export function PaymentsPage() {
  const totals = paymentRows.reduce(
    (accumulator, row) => {
      if (row.status === 'paid') {
        accumulator.paid += 1;
      }

      if (row.status === 'pending') {
        accumulator.pending += 1;
      }

      if (row.status === 'failed') {
        accumulator.failed += 1;
      }

      return accumulator;
    },
    { paid: 0, pending: 0, failed: 0 },
  );

  return (
    <div className="page-stack">
      <PageHeader title="Payments" subtitle="Track subscriptions and billing status" />
      <section className="stats-grid stats-grid-3">
        <StatCard label="Paid" value={totals.paid} tone="success" />
        <StatCard label="Pending" value={totals.pending} tone="warning" />
        <StatCard label="Failed" value={totals.failed} tone="danger" />
      </section>

      <ListPanel title="Transactions" subtitle="Latest billing activity">
        <div className="table-scroll">
          <table className="data-table">
            <thead>
              <tr>
                <th>Customer</th>
                <th>Plan</th>
                <th>Amount</th>
                <th>Status</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              {paymentRows.map((row) => (
                <tr key={row.id}>
                  <td>{row.customer}</td>
                  <td>{row.plan}</td>
                  <td>{row.amount}</td>
                  <td><Badge tone={pageTone(row.status)}>{row.status}</Badge></td>
                  <td>{row.date}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </ListPanel>
    </div>
  );
}

export function SettingsPage() {
  return (
    <div className="page-stack">
      <PageHeader title="Settings" subtitle="Configure the admin dashboard and moderation workflow" />

      <div className="settings-grid">
        {settingsSections.map((section) => (
          <section key={section.title} className="card settings-card">
            <h2 className="panel-title">{section.title}</h2>
            <div className="settings-list">
              {section.items.map((item) => (
                <label key={item} className="setting-row">
                  <span>{item}</span>
                  <span className="setting-toggle" />
                </label>
              ))}
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
