import { useEffect, useMemo, useState } from 'react';
import { type ModerationRequest, type ModerationStatus, loadPendingCandidates } from './mockModerationAdapter';
import { navigateToPath } from '../../navigation';

function matchesQuery(request: ModerationRequest, query: string) {
  if (!query) {
    return true;
  }

  const normalized = query.toLowerCase();
  return [request.name, request.summary, request.source, request.submittedBy, request.placeDetails.name]
    .join(' ')
    .toLowerCase()
    .includes(normalized);
}

function formatStatus(status: ModerationStatus) {
  return status.charAt(0).toUpperCase() + status.slice(1);
}

export default function ModerationPage() {
  const [search, setSearch] = useState('');
  const [filterType, setFilterType] = useState<'all-pending' | 'all'>('all-pending');
  const [filterStatus, setFilterStatus] = useState<ModerationStatus | 'All'>('All');

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [simulateError, setSimulateError] = useState(false);
  const [reloadToken, setReloadToken] = useState(0);
  const [requests, setRequests] = useState<ModerationRequest[]>([]);

  useEffect(() => {
    let isCancelled = false;

    setLoading(true);
    setError('');

    loadPendingCandidates(simulateError)
      .then((items) => {
        if (!isCancelled) {
          setRequests(items);
        }
      })
      .catch((loadError: unknown) => {
        if (!isCancelled) {
          setError(loadError instanceof Error ? loadError.message : 'Unable to load moderation queue.');
        }
      })
      .finally(() => {
        if (!isCancelled) {
          setLoading(false);
        }
      });

    return () => {
      isCancelled = true;
    };
  }, [reloadToken, simulateError]);

  const visibleRequests = useMemo(() => {
    return requests.filter((request) => {
      if (filterType === 'all-pending' && request.status !== 'pending') {
        return false;
      }

      if (filterStatus !== 'All' && request.status !== filterStatus) {
        return false;
      }

      return matchesQuery(request, search);
    });
  }, [filterStatus, filterType, requests, search]);

  const handleDecision = (requestId: string, newStatus: ModerationStatus) => {
    setRequests((current) => current.map((request) => (request.id === requestId ? { ...request, status: newStatus } : request)));
  };

  const stats = useMemo(
    () => ({
      total: requests.length,
      pending: requests.filter((request) => request.status === 'pending').length,
      approved: requests.filter((request) => request.status === 'approved').length,
    }),
    [requests],
  );

  return (
    <section className="moderation-page">
      <header className="main-header moderation-header">
        <div>
          <h2 className="page-title">Moderation</h2>
          <p className="page-subtitle">Review pending candidates without waiting for backend data.</p>
        </div>
        <div className="moderation-meta">
          <span className="queue-pill">{visibleRequests.length} pending</span>
          <button type="button" className="secondary-btn" onClick={() => setReloadToken((value) => value + 1)}>
            Refresh
          </button>
          <button
            type="button"
            className={`secondary-btn ${simulateError ? 'secondary-btn-active' : ''}`}
            onClick={() => setSimulateError((value) => !value)}
          >
            {simulateError ? 'Error mode on' : 'Simulate error'}
          </button>
        </div>
      </header>

      <div className="moderation-summary">
        <div className="summary-card card">
          <div className="summary-label">Total</div>
          <div className="summary-value">{stats.total}</div>
        </div>
        <div className="summary-card card">
          <div className="summary-label">Pending</div>
          <div className="summary-value">{stats.pending}</div>
        </div>
        <div className="summary-card card">
          <div className="summary-label">Approved</div>
          <div className="summary-value">{stats.approved}</div>
        </div>
      </div>

      <div className="moderation-toolbar card">
        <label className="field">
          <span className="field-label">Search</span>
          <input
            className="control-input"
            type="search"
            placeholder="Search by title, source, or reason"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
        </label>

        <label className="field">
          <span className="field-label">Filter</span>
          <select className="control-input" value={filterType} onChange={(event) => setFilterType(event.target.value as 'all-pending' | 'all')}>
            <option value="all-pending">All pending</option>
            <option value="all">All</option>
          </select>
        </label>

        <label className="field">
          <span className="field-label">Status</span>
          <select className="control-input" value={filterStatus} onChange={(e) => setFilterStatus(e.target.value as ModerationStatus | 'All')}>
            <option value="All">All</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
          </select>
        </label>
      </div>

      {loading ? (
        <div className="state-card card" role="status" aria-live="polite">
          <div className="state-title">Loading moderation queue</div>
          <div className="state-copy">Fetching mock candidates so the page works before backend integration.</div>
        </div>
      ) : error ? (
        <div className="state-card card state-error" role="alert">
          <div className="state-title">Something went wrong</div>
          <div className="state-copy">{error}</div>
          <button type="button" className="primary-btn" onClick={() => setReloadToken((value) => value + 1)}>
            Retry
          </button>
        </div>
      ) : visibleRequests.length === 0 ? (
        <div className="state-card card">
          <div className="state-title">No requests found</div>
          <div className="state-copy">Try another search term or clear the selected filter.</div>
        </div>
      ) : (
        <div className="card moderation-table-card">
          <div className="moderation-table-header">
            <h3 className="card-title">Pending Candidates</h3>
            <span className="moderation-count">{visibleRequests.length} items</span>
          </div>

          <div className="moderation-table-scroll">
            <table className="moderation-table">
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
                {visibleRequests.map((request) => (
                  <tr key={request.id}>
                    <td>
                      <div className="candidate-cell">
                        <div className="candidate-title">{request.name}</div>
                        <div className="candidate-subtitle">{request.source}</div>
                      </div>
                    </td>
                    <td>{request.submittedAt}</td>
                    <td>
                      <div className="candidate-submitter">{request.submittedBy}</div>
                    </td>
                    <td>
                      <div className={`status-pill status-${request.status}`}>{formatStatus(request.status)}</div>
                    </td>
                    <td>
                      <div className="table-actions">
                        <button type="button" className="approve-btn" onClick={() => handleDecision(request.id, 'approved')}>
                          Approve
                        </button>
                        <button type="button" className="reject-btn" onClick={() => handleDecision(request.id, 'rejected')}>
                          Reject
                        </button>
                        <a className="secondary-btn view-link" href={`/admin/moderation/${request.id}`} onClick={(event) => { event.preventDefault(); navigateToPath(`/admin/moderation/${request.id}`); }}>
                          View
                        </a>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </section>
  );
}