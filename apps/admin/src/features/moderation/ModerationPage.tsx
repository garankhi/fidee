import { useEffect, useMemo, useState } from 'react';
import {
  type CandidateFilter,
  type CandidateSort,
  type ModerationCandidate,
  loadPendingCandidates,
} from './mockModerationAdapter';

function formatDate(value: string) {
  return new Intl.DateTimeFormat('en', {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value));
}

function matchesQuery(candidate: ModerationCandidate, query: string) {
  if (!query) {
    return true;
  }

  const normalized = query.toLowerCase();
  return [candidate.title, candidate.summary, candidate.source, candidate.reason]
    .join(' ')
    .toLowerCase()
    .includes(normalized);
}

function applySort(candidates: ModerationCandidate[], sortBy: CandidateSort) {
  return [...candidates].sort((left, right) => {
    if (sortBy === 'score') {
      return right.score - left.score;
    }

    return new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime();
  });
}

export default function ModerationPage() {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<CandidateFilter>('all');
  const [sortBy, setSortBy] = useState<CandidateSort>('newest');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [simulateError, setSimulateError] = useState(false);
  const [reloadToken, setReloadToken] = useState(0);
  const [candidates, setCandidates] = useState<ModerationCandidate[]>([]);

  useEffect(() => {
    let isCancelled = false;

    setLoading(true);
    setError('');

    loadPendingCandidates(simulateError)
      .then((items) => {
        if (!isCancelled) {
          setCandidates(items);
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

  const visibleCandidates = useMemo(() => {
    const filtered = candidates.filter((candidate) => {
      const typeMatches = filter === 'all' || candidate.type === filter;
      return typeMatches && matchesQuery(candidate, search);
    });

    return applySort(filtered, sortBy);
  }, [candidates, filter, search, sortBy]);

  const handleDecision = (candidateId: string) => {
    setCandidates((current) => current.filter((candidate) => candidate.id !== candidateId));
  };

  return (
    <section className="moderation-page">
      <header className="main-header moderation-header">
        <div>
          <h2 className="page-title">Moderation</h2>
          <p className="page-subtitle">Review pending candidates without waiting for backend data.</p>
        </div>
        <div className="moderation-meta">
          <span className="queue-pill">{visibleCandidates.length} pending</span>
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
          <select className="control-input" value={filter} onChange={(event) => setFilter(event.target.value as CandidateFilter)}>
            <option value="all">All pending</option>
            <option value="place">Places</option>
            <option value="review">Reviews</option>
            <option value="user">Users</option>
          </select>
        </label>

        <label className="field">
          <span className="field-label">Sort</span>
          <select className="control-input" value={sortBy} onChange={(event) => setSortBy(event.target.value as CandidateSort)}>
            <option value="newest">Newest first</option>
            <option value="score">Highest score</option>
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
      ) : visibleCandidates.length === 0 ? (
        <div className="state-card card">
          <div className="state-title">No pending candidates</div>
          <div className="state-copy">Try another search term or clear the selected filter.</div>
        </div>
      ) : (
        <div className="card moderation-table-card">
          <div className="moderation-table-header">
            <h3 className="card-title">Pending Candidates</h3>
            <span className="moderation-count">{visibleCandidates.length} items</span>
          </div>

          <div className="moderation-table-scroll">
            <table className="moderation-table">
              <thead>
                <tr>
                  <th>Candidate</th>
                  <th>Type</th>
                  <th>Score</th>
                  <th>Submitted</th>
                  <th>Reason</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {visibleCandidates.map((candidate) => (
                  <tr key={candidate.id}>
                    <td>
                      <div className="candidate-cell">
                        <div className="candidate-title">{candidate.title}</div>
                        <div className="candidate-subtitle">{candidate.source}</div>
                      </div>
                    </td>
                    <td>
                      <span className={`type-pill type-${candidate.type}`}>{candidate.type}</span>
                    </td>
                    <td>
                      <span className="score-pill">{candidate.score}</span>
                    </td>
                    <td>{formatDate(candidate.createdAt)}</td>
                    <td>
                      <div className="candidate-reason">{candidate.reason}</div>
                    </td>
                    <td>
                      <div className="table-actions">
                        <button type="button" className="approve-btn" onClick={() => handleDecision(candidate.id)}>
                          Approve
                        </button>
                        <button type="button" className="reject-btn" onClick={() => handleDecision(candidate.id)}>
                          Reject
                        </button>
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