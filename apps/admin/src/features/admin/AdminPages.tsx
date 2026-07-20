import { useEffect, useMemo, useState } from 'react';
import { navigateToPath } from '../../navigation';
import { Skeleton } from 'boneyard-js/react';
import {
  approveCandidate,
  createPlace,
  deletePlace,
  fetchCandidateDetail,
  fetchModerationRequests,
  fetchPlaces,
  fetchUsers,
  rejectCandidate,
  updatePlace,
  updateUserData,
  type AdminPlacePayload,
} from './adminApi';
import {
  type ModerationRequest,
  type ModerationStatus,
  type Place,
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
  return status.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
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
  return (
    <div className="page-stack">
      <PageHeader title="Dashboard" subtitle="Operational overview from live admin APIs." />

      <section className="stats-grid stats-grid-4">
        <StatCard label="Total Places" value="-" />
        <StatCard label="Active Users" value="-" />
        <StatCard label="Reviews Today" value="-" />
        <StatCard label="Pending Moderation" value="-" />
      </section>

      <section className="status-grid">
        <article className="card status-card status-card-warning">
          <div className="status-card-top">
            <span className="status-kicker">Pending</span>
            <strong>-</strong>
          </div>
          <p>Awaiting moderation</p>
          <button type="button" className="text-link" onClick={() => navigateToPath('/admin/moderation')}>
            Review now
          </button>
        </article>
        <article className="card status-card status-card-success">
          <div className="status-card-top">
            <span className="status-kicker">Approved</span>
            <strong>-</strong>
          </div>
          <p>Successfully published</p>
          <span className="status-footnote">Last 7 days</span>
        </article>
        <article className="card status-card status-card-danger">
          <div className="status-card-top">
            <span className="status-kicker">Rejected</span>
            <strong>-</strong>
          </div>
          <p>Declined submissions</p>
          <span className="status-footnote">Last 7 days</span>
        </article>
      </section>

      <section className="dashboard-grid">
        <ListPanel title="Activity Trend" subtitle="No analytics endpoint connected yet">
          <EmptyState />
        </ListPanel>

        <ListPanel title="Quick Stats" subtitle="System overview">
          <EmptyState />
        </ListPanel>
      </section>

      <section className="dashboard-grid dashboard-grid-secondary">
        <ListPanel title="Recent Activity" subtitle="Latest platform events">
          <EmptyState />
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
  const [requests, setRequests] = useState<ModerationRequest[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [apiError, setApiError] = useState<string | null>(null);
  const [pendingActionId, setPendingActionId] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    async function loadModerationRequests() {
      setIsLoading(true);
      try {
        const realRequests = await fetchModerationRequests(
          filterStatus === 'All'
            ? filterType === 'all-pending'
              ? 'PENDING_REVIEW'
              : undefined
            : filterStatus === 'approved'
              ? 'APPROVED'
              : filterStatus === 'rejected'
                ? 'REJECTED'
                : filterStatus === 'needs_more_info'
                  ? 'NEEDS_MORE_INFO'
                  : 'PENDING_REVIEW',
        );
        if (active) {
          setRequests(realRequests);
          setApiError(null);
        }
      } catch (error) {
        if (isAuthRejected(error)) {
          redirectToLogin();
          return;
        }

        console.error('Failed to load moderation requests:', error);
        if (active) {
          setRequests([]);
          setApiError('Không thể tải moderation từ API. Kiểm tra VITE_API_URL, deploy backend, hoặc quyền Admins.');
        }
      } finally {
        if (active) {
          setIsLoading(false);
        }
      }
    }

    loadModerationRequests();
    return () => {
      active = false;
    };
  }, [filterStatus, filterType]);

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

  const handleDecision = async (requestId: string, status: ModerationStatus) => {
    setPendingActionId(requestId);
    try {
      if (status === 'approved') {
        await approveCandidate(requestId);
      } else if (status === 'rejected') {
        await rejectCandidate(requestId, 'Rejected from admin moderation list.');
      }

      setRequests((current) =>
        status === 'approved'
          ? current.filter((request) => request.id !== requestId)
          : current.map((request) => (request.id === requestId ? { ...request, status } : request)),
      );
    } catch (error) {
      if (isAuthRejected(error)) {
        redirectToLogin();
        return;
      }
      console.error('Failed to update moderation request:', error);
      setApiError('Không thể cập nhật moderation request qua API.');
    } finally {
      setPendingActionId(null);
    }
  };

  return (
    <div className="page-stack">
      <PageHeader
        title="Moderation"
        subtitle="Review user-submitted places before they go live."
        action={<span className="queue-pill">{filteredRequests.length} items</span>}
      />

      <section className="stats-grid stats-grid-3">
        <StatCard label="Total" value={stats.total} />
        <StatCard label="Pending" value={stats.pending} tone="warning" />
        <StatCard label="Approved" value={stats.approved} tone="success" />
      </section>

      {apiError && (
        <div className="offline-banner">
          <span>⚠️</span>
          <span>{apiError}</span>
        </div>
      )}

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
            <option value="needs_more_info">Needs Info</option>
          </select>
        </label>
      </section>

      <ListPanel title="Pending Candidates" subtitle={`${filteredRequests.length} items`}>
        <Skeleton name="moderation-list" loading={isLoading} fallback={<UserSkeletonList />}>
          {filteredRequests.length === 0 ? (
            <EmptyState message="Không có quán user đề xuất từ API." />
          ) : (
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
                            {pendingActionId === request.id ? 'Saving...' : 'Approve'}
                          </button>
                          <button type="button" className="reject-btn" onClick={() => handleDecision(request.id, 'rejected')} disabled={pendingActionId === request.id}>
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
          )}
        </Skeleton>
      </ListPanel>
    </div>
  );
}

function EmptyState({ title = 'Không có dữ liệu', message = 'Chưa có dữ liệu thật từ API cho mục này.' }: { title?: string; message?: string }) {
  return (
    <div className="state-card">
      <strong>{title}</strong>
      <p>{message}</p>
    </div>
  );
}

export function ModerationDetailsPage({ requestId }: { requestId: string }) {
  const [request, setRequest] = useState<ModerationRequest | null>(null);
  const [actionTaken, setActionTaken] = useState<ModerationStatus | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [apiError, setApiError] = useState<string | null>(null);
  const [detailMeta, setDetailMeta] = useState<{
    gpsProof: Array<Record<string, unknown> & { mediaUrl?: string | null }>;
    duplicateHints: Array<Record<string, unknown>>;
  }>({ gpsProof: [], duplicateHints: [] });

  useEffect(() => {
    let active = true;

    async function loadCandidateDetail() {
      setIsLoading(true);
      try {
        const detail = await fetchCandidateDetail(requestId);
        if (active) {
          setRequest(detail.request);
          setDetailMeta({ gpsProof: detail.gpsProof, duplicateHints: detail.duplicateHints });
          setApiError(null);
        }
      } catch (error) {
        if (isAuthRejected(error)) {
          redirectToLogin();
          return;
        }

        console.error('Failed to load candidate detail:', error);
        if (active) {
          setRequest(null);
          setApiError('Không thể tải chi tiết candidate từ API.');
        }
      } finally {
        if (active) {
          setIsLoading(false);
        }
      }
    }

    loadCandidateDetail();
    return () => {
      active = false;
    };
  }, [requestId]);

  if (isLoading && !request) {
    return (
      <div className="page-stack">
        <ListPanel title="Loading request">
          <UserSkeletonList />
        </ListPanel>
      </div>
    );
  }

  if (!request) {
    return (
      <div className="page-stack">
        <ListPanel title="Request not found" subtitle={apiError || 'The moderation request you opened no longer exists.'}>
          <button type="button" className="primary-btn" onClick={() => navigateToPath('/admin/moderation')}>
            Back to Moderation
          </button>
        </ListPanel>
      </div>
    );
  }

  const handleApprove = async () => {
    setActionTaken('approved');
    try {
      await approveCandidate(request.id);
      window.setTimeout(() => navigateToPath('/admin/moderation'), 800);
    } catch (error) {
      setActionTaken(null);
      if (isAuthRejected(error)) {
        redirectToLogin();
        return;
      }
      console.error('Failed to approve candidate:', error);
    }
  };

  const handleReject = async () => {
    setActionTaken('rejected');
    try {
      await rejectCandidate(request.id, 'Rejected from admin detail page.');
      window.setTimeout(() => navigateToPath('/admin/moderation'), 800);
    } catch (error) {
      setActionTaken(null);
      if (isAuthRejected(error)) {
        redirectToLogin();
        return;
      }
      console.error('Failed to reject candidate:', error);
    }
  };

  const hasMedia =
    Boolean(request.images?.menu?.length) ||
    Boolean(request.images?.space?.length) ||
    Boolean(request.images?.dishes?.length);
  const gpsProofImages = detailMeta.gpsProof
    .map((proof) => proof.mediaUrl)
    .filter((url): url is string => typeof url === 'string' && url.length > 0);

  return (
    <div className="page-stack moderation-details-page">
      <PageHeader
        title={request.placeDetails.name}
        subtitle="Review submission details"
        action={<button type="button" className="secondary-btn" onClick={() => navigateToPath('/admin/moderation')}>Close</button>}
      />

      {actionTaken ? (
        <div className={cx('card', 'state-card', actionTaken === 'approved' ? 'state-card-success' : 'state-card-danger')}>
          {actionTaken === 'approved' ? 'Approving request...' : 'Rejecting request...'}
        </div>
      ) : null}

      {apiError && (
        <div className="offline-banner">
          <span>⚠️</span>
          <span>{apiError}</span>
        </div>
      )}

      <Skeleton name="moderation-detail" loading={isLoading} fallback={<UserSkeletonList />}>
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
            {hasMedia ? (
              <div className="media-groups">
              {request.images?.menu?.length ? (
                <div className="gallery">
                  <div className="gallery-title">Menu</div>
                  <div className="images-row">
                    {request.images.menu.map((src) => (
                      <img key={src} src={src} alt="menu" />
                    ))}
                  </div>
                </div>
              ) : null}
              {request.images?.space?.length ? (
                <div className="gallery">
                  <div className="gallery-title">Space</div>
                  <div className="images-row">
                    {request.images.space.map((src) => (
                      <img key={src} src={src} alt="space" />
                    ))}
                  </div>
                </div>
              ) : null}
              {request.images?.dishes?.length ? (
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
            ) : (
              <EmptyState message="Bài đề xuất này chưa có ảnh từ API." />
            )}
          </section>

          <section className="card details-card">
            <h2 className="panel-title">Verification</h2>
            <div className="details-grid details-grid-2">
              <div>
                <span className="detail-label">GPS proof</span>
                <strong>{detailMeta.gpsProof.length} check-ins nearby</strong>
              </div>
              <div>
                <span className="detail-label">Duplicate hints</span>
                <strong>{detailMeta.duplicateHints.length} nearby places</strong>
              </div>
            </div>
            {gpsProofImages.length ? (
              <div className="gallery detail-block">
                <div className="gallery-title">Check-in Proof</div>
                <div className="images-row">
                  {gpsProofImages.map((src) => (
                    <img key={src} src={src} alt="check-in proof" />
                  ))}
                </div>
              </div>
            ) : null}
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
      </Skeleton>
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
  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [apiError, setApiError] = useState<string | null>(null);
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
          setApiError(null);
        }
      } catch (error) {
        if (isAuthRejected(error)) {
          redirectToLogin();
          return;
        }

        console.error('Failed to load users:', error);
        if (active) {
          setUsers([]);
          setApiError('Không thể tải users từ API. Kiểm tra VITE_API_URL, deploy backend, hoặc quyền Admins.');
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

      {apiError && (
        <div className="offline-banner">
          <span>⚠️</span>
          <span>{apiError}</span>
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
                const updated = normalizeUser(await updateUserData(editingUser.id, editingUser));
                setUsers((prev) => prev.map((u) => u.id === updated.id ? updated : u));
                setToast({
                    title: 'Cập nhật thành công (API thực)',
                    message: `Đã lưu thông tin người dùng ${editingUser.username} lên hệ thống thực.`
                  });
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
  const emptyPlaceForm: AdminPlacePayload = {
    name: '',
    category: 'other',
    address: '',
    coordinates: { lat: 10.7769, lng: 106.7009 },
    visibility: 'PUBLIC',
    status: 'APPROVED',
    openTime: '',
    closeTime: '',
    priceMin: null,
    priceMax: null,
    phoneNumber: '',
    description: '',
  };

  const [search, setSearch] = useState('');
  const [places, setPlaces] = useState<Place[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [apiError, setApiError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [isPlaceModalOpen, setIsPlaceModalOpen] = useState(false);
  const [editingPlace, setEditingPlace] = useState<Place | null>(null);
  const [placeForm, setPlaceForm] = useState<AdminPlacePayload>(emptyPlaceForm);

  useEffect(() => {
    let active = true;

    async function loadPlaces() {
      setIsLoading(true);
      try {
        const realPlaces = await fetchPlaces();
        if (active) {
          setPlaces(realPlaces);
          setApiError(null);
        }
      } catch (error) {
        if (isAuthRejected(error)) {
          redirectToLogin();
          return;
        }

        console.error('Failed to load places:', error);
        if (active) {
          setPlaces([]);
          setApiError('Không thể tải places từ API. Kiểm tra VITE_API_URL, deploy backend, hoặc quyền Admins.');
        }
      } finally {
        if (active) {
          setIsLoading(false);
        }
      }
    }

    loadPlaces();
    return () => {
      active = false;
    };
  }, []);

  const filteredPlaces = useMemo(() => {
    const query = search.trim().toLowerCase();
    return places.filter((place) => query === '' || [place.name, place.address, place.description, place.category || ''].join(' ').toLowerCase().includes(query));
  }, [places, search]);

  const totalReviews = places.reduce((sum, place) => sum + place.reviews, 0);
  const avgRating = places.length === 0 ? '0.0' : (places.reduce((sum, place) => sum + place.rating, 0) / places.length).toFixed(1);

  const openPlaceForm = (place?: Place) => {
    if (place) {
      setIsPlaceModalOpen(true);
      setEditingPlace(place);
      setPlaceForm({
        name: place.name,
        category: place.category || 'other',
        address: place.address,
        coordinates: place.coordinates || emptyPlaceForm.coordinates,
        visibility: place.visibility || 'PUBLIC',
        status: place.status || 'APPROVED',
        openTime: place.openTime || '',
        closeTime: place.closeTime || '',
        priceMin: place.priceMin ?? null,
        priceMax: place.priceMax ?? null,
        phoneNumber: place.phone,
        description: place.description,
      });
      return;
    }

    setEditingPlace(null);
    setPlaceForm(emptyPlaceForm);
    setIsPlaceModalOpen(true);
  };

  const closePlaceForm = () => {
    setIsPlaceModalOpen(false);
    setEditingPlace(null);
    setPlaceForm(emptyPlaceForm);
  };

  const handleSavePlace = async (event: React.FormEvent) => {
    event.preventDefault();
    setIsSaving(true);
    try {
      if (editingPlace) {
        const updated = await updatePlace(editingPlace.id, placeForm);
        setPlaces((current) => current.map((place) => place.id === updated.id ? updated : place));
      } else {
        const created = await createPlace(placeForm);
        setPlaces((current) => [created, ...current]);
      }
      closePlaceForm();
    } catch (error) {
      if (isAuthRejected(error)) {
        redirectToLogin();
        return;
      }
      console.error('Failed to save place:', error);
      setApiError('Không thể lưu place qua API.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleDeletePlace = async (placeId: string) => {
    setIsSaving(true);
    try {
      await deletePlace(placeId);
      setPlaces((current) => current.filter((place) => place.id !== placeId));
    } catch (error) {
      if (isAuthRejected(error)) {
        redirectToLogin();
        return;
      }
      console.error('Failed to delete place:', error);
      setApiError('Không thể xóa place qua API.');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="page-stack">
      <PageHeader title="Places" subtitle="Manage approved restaurant and venue listings" action={<button className="primary-btn" type="button" onClick={() => openPlaceForm()}>Add Place</button>} />
      <section className="stats-grid stats-grid-3">
        <StatCard label="Total Places" value={places.length} />
        <StatCard label="Total Reviews" value={totalReviews} />
        <StatCard label="Avg Rating" value={`${avgRating}/5`} tone="success" />
      </section>

      {apiError && (
        <div className="offline-banner">
          <span>⚠️</span>
          <span>{apiError}</span>
        </div>
      )}

      <section className="card toolbar-card">
        <SearchField value={search} onChange={setSearch} placeholder="Search places by name, address, or description..." />
      </section>

      <Skeleton name="places-grid" loading={isLoading} fallback={<UserSkeletonList />}>
        <section className="cards-grid">
          {filteredPlaces.map((place) => (
            <article key={place.id} className="card place-card">
              <div className="place-card-head">
                <div>
                  <h2>{place.name}</h2>
                  <div className="rating-row">{renderStars(place.rating)} <span>{place.rating.toFixed(1)}/5</span></div>
                </div>
                <div className="card-actions-inline">
                  <button type="button" className="icon-btn" onClick={() => openPlaceForm(place)}>✏️</button>
                  <button type="button" className="icon-btn" onClick={() => handleDeletePlace(place.id)} disabled={isSaving}>🗑️</button>
                </div>
              </div>
              <div className="place-info-row">📍 {place.address || 'No address'}</div>
              <p>{place.description || 'No description yet.'}</p>
              <div className="place-footer">
                <div className="mini-meta">💬 {place.reviews} reviews</div>
                <div className="pill-list">
                  <span className="amenity-pill">{place.category || 'other'}</span>
                  {place.status ? <span className="amenity-pill">{place.status.toLowerCase()}</span> : null}
                </div>
              </div>
            </article>
          ))}
        </section>
      </Skeleton>

      {isPlaceModalOpen && (
        <div className="modal-overlay" onClick={() => (isSaving ? null : closePlaceForm())}>
          <div className="modal-container" onClick={(event) => event.stopPropagation()}>
            <div className="modal-header">
              <h2>{editingPlace ? 'Edit Place' : 'Add Place'}</h2>
              <button type="button" className="modal-close-btn" onClick={closePlaceForm} disabled={isSaving}>
                ✕
              </button>
            </div>
            <form onSubmit={handleSavePlace}>
              <div className="form-stack">
                <label className="field">
                  <span className="field-label">Name</span>
                  <input className="control-input" required value={placeForm.name} onChange={(event) => setPlaceForm({ ...placeForm, name: event.target.value })} />
                </label>
                <div className="form-row">
                  <label className="field">
                    <span className="field-label">Category</span>
                    <select className="control-input" value={placeForm.category} onChange={(event) => setPlaceForm({ ...placeForm, category: event.target.value })}>
                      <option value="cafe">Cafe</option>
                      <option value="restaurant">Restaurant</option>
                      <option value="hotel">Hotel</option>
                      <option value="tourist_attraction">Tourist attraction</option>
                      <option value="office">Office</option>
                      <option value="shopping">Shopping</option>
                      <option value="other">Other</option>
                    </select>
                  </label>
                  <label className="field">
                    <span className="field-label">Visibility</span>
                    <select className="control-input" value={placeForm.visibility} onChange={(event) => setPlaceForm({ ...placeForm, visibility: event.target.value as AdminPlacePayload['visibility'] })}>
                      <option value="PUBLIC">Public</option>
                      <option value="FRIENDS">Friends</option>
                      <option value="PRIVATE">Private</option>
                    </select>
                  </label>
                </div>
                <label className="field">
                  <span className="field-label">Address</span>
                  <input className="control-input" value={placeForm.address} onChange={(event) => setPlaceForm({ ...placeForm, address: event.target.value })} />
                </label>
                <div className="form-row">
                  <label className="field">
                    <span className="field-label">Latitude</span>
                    <input className="control-input" type="number" step="any" required value={placeForm.coordinates.lat} onChange={(event) => setPlaceForm({ ...placeForm, coordinates: { ...placeForm.coordinates, lat: Number(event.target.value) } })} />
                  </label>
                  <label className="field">
                    <span className="field-label">Longitude</span>
                    <input className="control-input" type="number" step="any" required value={placeForm.coordinates.lng} onChange={(event) => setPlaceForm({ ...placeForm, coordinates: { ...placeForm.coordinates, lng: Number(event.target.value) } })} />
                  </label>
                </div>
                <div className="form-row">
                  <label className="field">
                    <span className="field-label">Open</span>
                    <input className="control-input" type="time" value={placeForm.openTime} onChange={(event) => setPlaceForm({ ...placeForm, openTime: event.target.value })} />
                  </label>
                  <label className="field">
                    <span className="field-label">Close</span>
                    <input className="control-input" type="time" value={placeForm.closeTime} onChange={(event) => setPlaceForm({ ...placeForm, closeTime: event.target.value })} />
                  </label>
                </div>
                <label className="field">
                  <span className="field-label">Phone</span>
                  <input className="control-input" value={placeForm.phoneNumber} onChange={(event) => setPlaceForm({ ...placeForm, phoneNumber: event.target.value })} />
                </label>
                <label className="field">
                  <span className="field-label">Description</span>
                  <textarea className="control-input" rows={4} value={placeForm.description} onChange={(event) => setPlaceForm({ ...placeForm, description: event.target.value })} />
                </label>
              </div>
              <div className="form-actions">
                <button type="button" className="secondary-btn" onClick={closePlaceForm} disabled={isSaving}>
                  Cancel
                </button>
                <button type="submit" className="primary-btn" disabled={isSaving}>
                  {isSaving ? 'Saving...' : 'Save Place'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

export function ReviewsPage() {
  const [search, setSearch] = useState('');
  const [filterRating, setFilterRating] = useState<'all' | '5' | '4' | '3' | '2' | '1'>('all');

  const reviews = useMemo(() => {
    void search;
    void filterRating;
    return [] as Array<{ id: string; placeName: string; author: string; rating: number; content: string; date: string }>;
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
        {reviews.length === 0 ? <EmptyState message="Chưa có API reviews cho admin." /> : <div className="list-stack">
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
        </div>}
      </ListPanel>
    </div>
  );
}

export function AnalyticsPage() {
  return (
    <div className="page-stack">
      <PageHeader title="Analytics" subtitle="Performance charts and operational trends" action={<button className="secondary-btn" type="button">Export</button>} />

      <section className="stats-grid stats-grid-4">
        <StatCard label="Total Reported Content" value="-" />
        <StatCard label="Spam Reports" value="-" />
        <StatCard label="Inappropriate Content" value="-" />
        <StatCard label="Resolved" value="-" />
      </section>

      <section className="dashboard-grid">
        <ListPanel title="User Engagement" subtitle="Weekly activity overview">
          <EmptyState message="Chưa có API analytics cho admin." />
        </ListPanel>

        <ListPanel title="New Signups" subtitle="Weekly registration trend">
          <EmptyState message="Chưa có API signup analytics cho admin." />
        </ListPanel>
      </section>

      <ListPanel title="Category Performance" subtitle="Restaurant category breakdown">
        <EmptyState message="Chưa có API category performance cho admin." />
      </ListPanel>
    </div>
  );
}

export function ActivityPage() {
  const [search, setSearch] = useState('');
  const [filterType, setFilterType] = useState<'all' | string>('all');

  const logs = useMemo(() => {
    void search;
    void filterType;
    return [] as Array<{ id: number; user: string; action: string; target: string; timestamp: string; icon: string }>;
  }, [filterType, search]);

  return (
    <div className="page-stack">
      <PageHeader title="Activity Logs" subtitle="Track all user and system activities on the platform." />
      <section className="stats-grid stats-grid-3">
        <StatCard label="Total Activities" value="-" />
        <StatCard label="Today" value="-" />
        <StatCard label="This Week" value="-" />
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
        {logs.length === 0 ? <EmptyState message="Chưa có API activity logs cho admin." /> : <div className="list-stack">
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
        </div>}
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
        <StatCard label="Total Reported Content" value="-" />
        <StatCard label="Spam Reports" value="-" />
        <StatCard label="Inappropriate Content" value="-" />
        <StatCard label="Resolved" value="-" />
      </section>

      <section className="dashboard-grid">
        <ListPanel title="User Engagement" subtitle="Weekly activity overview">
          <EmptyState message="Chưa có API reports cho admin." />
        </ListPanel>
        <ListPanel title="Signups Trend" subtitle="Weekly registration trend">
          <EmptyState message="Chưa có API signup reports cho admin." />
        </ListPanel>
      </section>

      <ListPanel title="Key Insights" subtitle="What the team should focus on next">
        <EmptyState message="Chưa có API insights cho admin." />
      </ListPanel>
    </div>
  );
}

export function ContentPage() {
  const [search, setSearch] = useState('');

  const items = useMemo(() => {
    void search;
    return [] as Array<{ id: string; title: string; type: string; category: string; status: 'draft' | 'published' | 'needs review'; views: number; createdAt: string }>;
  }, [search]);

  return (
    <div className="page-stack">
      <PageHeader title="Content" subtitle="Manage featured pages, copy, and content blocks" />
      <section className="stats-grid stats-grid-3">
        <StatCard label="Total Content" value="-" />
        <StatCard label="Published" value="-" />
        <StatCard label="Needs Review" value="-" />
      </section>

      <section className="card toolbar-card">
        <SearchField value={search} onChange={setSearch} placeholder="Search by title, owner, or category..." />
      </section>

      <ListPanel title="Content Items" subtitle={`${items.length} entries`}>
        {items.length === 0 ? <EmptyState message="Chưa có API content cho admin." /> : (
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
        )}
      </ListPanel>
    </div>
  );
}

export function PaymentsPage() {
  const paymentRows: Array<{ id: string; customer: string; plan: string; amount: string; status: 'paid' | 'pending' | 'failed'; date: string }> = [];
  const totals = { paid: 0, pending: 0, failed: 0 };

  return (
    <div className="page-stack">
      <PageHeader title="Payments" subtitle="Track subscriptions and billing status" />
      <section className="stats-grid stats-grid-3">
        <StatCard label="Paid" value={totals.paid} tone="success" />
        <StatCard label="Pending" value={totals.pending} tone="warning" />
        <StatCard label="Failed" value={totals.failed} tone="danger" />
      </section>

      <ListPanel title="Transactions" subtitle="Latest billing activity">
        {paymentRows.length === 0 ? <EmptyState message="Chưa có API payments cho admin." /> : (
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
        )}
      </ListPanel>
    </div>
  );
}

export function SettingsPage() {
  const settingsSections: Array<{ title: string; items: string[] }> = [];

  return (
    <div className="page-stack">
      <PageHeader title="Settings" subtitle="Configure the admin dashboard and moderation workflow" />

      <div className="settings-grid">
        {settingsSections.length === 0 ? <EmptyState message="Chưa có API settings cho admin." /> : settingsSections.map((section) => (
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
