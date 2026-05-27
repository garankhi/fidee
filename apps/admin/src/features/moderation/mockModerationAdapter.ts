export type CandidateType = 'place' | 'review' | 'user';

export type CandidateSort = 'newest' | 'score';

export type CandidateFilter = 'all' | CandidateType;

export interface ModerationCandidate {
  id: string;
  title: string;
  summary: string;
  type: CandidateType;
  source: string;
  score: number;
  createdAt: string;
  reason: string;
}

const MOCK_PENDING_CANDIDATES: ModerationCandidate[] = [
  {
    id: 'cand-1001',
    title: 'Rooftop Bar Saigon',
    summary: 'New place submission awaiting review.',
    type: 'place',
    source: 'Community submission',
    score: 97,
    createdAt: '2026-05-27T08:15:00.000Z',
    reason: 'High visibility listing needs manual approval.',
  },
  {
    id: 'cand-1002',
    title: 'Spam review on Banh Mi Huynh Hoa',
    summary: 'Review contains promotional language and suspicious links.',
    type: 'review',
    source: 'Auto-flagged',
    score: 84,
    createdAt: '2026-05-27T07:40:00.000Z',
    reason: 'Detected suspicious outbound URLs.',
  },
  {
    id: 'cand-1003',
    title: 'Foodie_SG profile badge request',
    summary: 'User submitted a badge appeal for gold status.',
    type: 'user',
    source: 'User request',
    score: 71,
    createdAt: '2026-05-26T18:20:00.000Z',
    reason: 'Badge review requires moderator approval.',
  },
  {
    id: 'cand-1004',
    title: 'Hidden cafe in District 3',
    summary: 'Place edit request includes new photos and opening hours.',
    type: 'place',
    source: 'Contributor edit',
    score: 88,
    createdAt: '2026-05-26T16:05:00.000Z',
    reason: 'Critical place metadata was changed.',
  },
  {
    id: 'cand-1005',
    title: 'Off-topic review for train station',
    summary: 'Review is unrelated to the place and seems low quality.',
    type: 'review',
    source: 'Trust & safety queue',
    score: 64,
    createdAt: '2026-05-25T22:45:00.000Z',
    reason: 'Likely irrelevant content.',
  },
  {
    id: 'cand-1006',
    title: 'Traveler account verification',
    summary: 'New user needs manual verification before publishing content.',
    type: 'user',
    source: 'Verification flow',
    score: 92,
    createdAt: '2026-05-25T12:10:00.000Z',
    reason: 'Pending identity confirmation.',
  },
];

const delay = (milliseconds: number) => new Promise((resolve) => setTimeout(resolve, milliseconds));

export async function loadPendingCandidates(simulateError = false) {
  await delay(250);

  if (simulateError) {
    throw new Error('Unable to load moderation queue.');
  }

  return MOCK_PENDING_CANDIDATES;
}