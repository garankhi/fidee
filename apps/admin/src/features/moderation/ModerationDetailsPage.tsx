import { useState } from 'react';
import { mockModerationRequests } from './mockModerationAdapter';
import { navigateToPath } from '../../navigation';

interface ModerationDetailsPageProps {
  requestId: string;
}

function renderStars(rating: number) {
  return Array.from({ length: 5 }, (_, index) => (
    <span key={index} className={`star ${index < rating ? 'filled' : ''}`}>
      ★
    </span>
  ));
}

export default function ModerationDetailsPage({ requestId }: ModerationDetailsPageProps) {
  const [actionTaken, setActionTaken] = useState<'approved' | 'rejected' | null>(null);

  const request = mockModerationRequests.find((item) => item.id === requestId);

  if (!request) {
    return (
      <div className="moderation-page">
        <div className="state-card card">
          <div className="state-title">Request not found</div>
          <div className="state-copy">The moderation request you opened no longer exists.</div>
          <button type="button" className="primary-btn" onClick={() => navigateToPath('/admin/moderation')}>
            Back to Moderation
          </button>
        </div>
      </div>
    );
  }

  const handleApprove = () => {
    setActionTaken('approved');
    window.setTimeout(() => {
      navigateToPath('/admin/moderation');
    }, 1500);
  };

  const handleReject = () => {
    setActionTaken('rejected');
    window.setTimeout(() => {
      navigateToPath('/admin/moderation');
    }, 1500);
  };

  return (
    <section className="moderation-page moderation-details-page">
      <header className="main-header moderation-header">
        <div>
          <h2 className="page-title">{request.placeDetails.name}</h2>
          <p className="page-subtitle">Review submission details</p>
        </div>
        <button type="button" className="secondary-btn" onClick={() => navigateToPath('/admin/moderation')}>
          Close
        </button>
      </header>

      {actionTaken && (
        <div className={`state-card card ${actionTaken === 'approved' ? 'action-approved' : 'action-rejected'}`}>
          <div className="state-title">
            {actionTaken === 'approved' ? 'Request approved successfully' : 'Request rejected successfully'}
          </div>
        </div>
      )}

      <div className="details-layout">
        <div className="details-main">
          <div className="card details-card">
            <h3 className="card-title">Submission Information</h3>
            <div className="details-grid">
              <div>
                <div className="detail-label">Submitted By</div>
                <div className="detail-value">{request.submittedBy}</div>
              </div>
              <div>
                <div className="detail-label">Submitted</div>
                <div className="detail-value">{request.submittedAt}</div>
              </div>
              <div>
                <div className="detail-label">Status</div>
                <div className={`status-pill status-${request.status}`}>{request.status}</div>
              </div>
              <div>
                <div className="detail-label">Source</div>
                <div className="detail-value">{request.source}</div>
              </div>
            </div>
            <div className="detail-block">
              <div className="detail-label">Summary</div>
              <div className="candidate-reason">{request.summary}</div>
            </div>
          </div>

          <div className="card details-card">
            <h3 className="card-title">Place Details</h3>
            <div className="detail-block">
              <div className="detail-label">Name</div>
              <div className="detail-value detail-value-lg">{request.placeDetails.name}</div>
            </div>
            <div className="details-grid details-grid-2">
              <div>
                <div className="detail-label">Address</div>
                <div className="detail-value">{request.placeDetails.address}</div>
              </div>
              <div>
                <div className="detail-label">Phone</div>
                <div className="detail-value">{request.placeDetails.phone ?? '—'}</div>
              </div>
            </div>
            <div className="detail-block">
              <div className="detail-label">Description</div>
              <div className="candidate-reason">{request.placeDetails.description}</div>
            </div>
            <div className="detail-block">
              <div className="detail-label">Amenities</div>
              <div className="amenities-list">
                {request.placeDetails.amenities.map((amenity) => (
                  <span key={amenity} className="amenity-pill">
                    {amenity}
                  </span>
                ))}
              </div>
            </div>
          </div>

          {request.placeDetails.posterReview && (
            <div className="card details-card">
              <h3 className="card-title">Poster Review</h3>
              <div className="rating-stars">
                {renderStars(request.placeDetails.posterReview.rating)}
              </div>
              <div className="candidate-reason">{request.placeDetails.posterReview.text}</div>
            </div>
          )}

          <div className="card details-card">
            <h3 className="card-title">Media</h3>
            <div className="media-groups">
              <div className="gallery">
                <div className="gallery-title">Menu</div>
                <div className="images-row">
                  {request.placeDetails.images.menu.map((src, index) => (
                    <img key={`${src}-${index}`} src={src} alt="menu" />
                  ))}
                </div>
              </div>
              <div className="gallery">
                <div className="gallery-title">Space</div>
                <div className="images-row">
                  {request.placeDetails.images.space.map((src, index) => (
                    <img key={`${src}-${index}`} src={src} alt="space" />
                  ))}
                </div>
              </div>
              <div className="gallery">
                <div className="gallery-title">Dishes</div>
                <div className="images-row">
                  {request.placeDetails.images.dishes.map((src, index) => (
                    <img key={`${src}-${index}`} src={src} alt="dish" />
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="details-side">
          <div className="card details-card sticky-card">
            <h3 className="card-title">Actions</h3>
            <div className="table-actions details-actions">
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
          </div>

          <div className="card details-card">
            <h3 className="card-title">Submission Meta</h3>
            <div className="detail-label">Submitted by</div>
            <div className="detail-value">{request.submittedBy}</div>
            <div className="detail-label detail-spacer">Submitted at</div>
            <div className="detail-value">{request.submittedAt}</div>
          </div>
        </div>
      </div>
    </section>
  );
}
