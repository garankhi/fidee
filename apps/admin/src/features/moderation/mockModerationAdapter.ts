export type ModerationStatus = 'pending' | 'approved' | 'rejected';

export interface SpotDetails {
  name: string;
  address: string;
  phone?: string;
  description?: string;
  amenities: string[];
  images: {
    menu: string[];
    space: string[];
    dishes: string[];
  };
  posterReview?: {
    rating: number;
    text: string;
  };
}

export interface ModerationRequest {
  id: string;
  name: string;
  summary: string;
  source: string;
  submittedAt: string;
  submittedBy: string;
  status: ModerationStatus;
  placeDetails: SpotDetails;
}

const MOCK_PENDING_CANDIDATES: ModerationRequest[] = [
  {
    id: 'cand-1001',
    name: 'Rooftop Bar Saigon',
    summary: 'New place submission awaiting review.',
    source: 'Community submission',
    submittedAt: 'May 27, 2026 8:15 AM',
    submittedBy: 'nguyenminh',
    status: 'pending',
    placeDetails: {
      name: 'Rooftop Bar Saigon',
      address: '123 Nguyen Hue, District 1, HCMC',
      phone: '+84 28 1234 5678',
      description: 'A popular rooftop bar with panoramic city views and live music.',
      amenities: ['wifi', 'cash', 'restroom', 'outdoor'],
      images: {
        menu: ['https://placehold.co/400x300?text=menu1'],
        space: ['https://placehold.co/800x600?text=space1'],
        dishes: ['https://placehold.co/600x400?text=dish1'],
      },
      posterReview: { rating: 5, text: 'Amazing view and great cocktails!' },
    },
  },
  {
    id: 'cand-1002',
    name: 'Saigon Sunset Coffee',
    summary: 'New up spot submitted by community member.',
    source: 'Community submission',
    submittedAt: 'May 27, 2026 7:40 AM',
    submittedBy: 'phamlinh',
    status: 'pending',
    placeDetails: {
      name: 'Saigon Sunset Coffee',
      address: '12 Le Loi, District 1, HCMC',
      phone: '+84 28 1111 2222',
      description: 'Modern cafe with rooftop corner and sunset city view.',
      amenities: ['wifi', 'cash', 'restroom', 'outdoor'],
      images: {
        menu: ['https://placehold.co/400x300?text=menu3'],
        space: ['https://placehold.co/800x600?text=space3'],
        dishes: ['https://placehold.co/600x400?text=dish3'],
      },
      posterReview: { rating: 4, text: 'Comfy vibes and friendly staff.' },
    },
  },
  {
    id: 'cand-1003',
    name: 'Night Noodle Corner',
    summary: 'Up spot request with late-night opening hours.',
    source: 'Contributor edit',
    submittedAt: 'May 26, 2026 6:20 PM',
    submittedBy: 'foodie_sg',
    status: 'approved',
    placeDetails: {
      name: 'Night Noodle Corner',
      address: '88 Tran Hung Dao, District 5, HCMC',
      phone: '+84 28 7777 9999',
      description: 'Street-style noodle spot open until midnight.',
      amenities: ['cash', 'delivery', 'outdoor'],
      images: {
        menu: ['https://placehold.co/400x300?text=menu4'],
        space: ['https://placehold.co/800x600?text=space4'],
        dishes: ['https://placehold.co/600x400?text=dish4'],
      },
      posterReview: { rating: 4, text: 'Great broth and quick service.' },
    },
  },
  {
    id: 'cand-1004',
    name: 'Hidden cafe in District 3',
    summary: 'Up spot edit request includes new photos and opening hours.',
    source: 'Contributor edit',
    submittedAt: 'May 26, 2026 4:05 PM',
    submittedBy: 'jane.doe',
    status: 'pending',
    placeDetails: {
      name: 'Hidden cafe in District 3',
      address: '45 Vo Van Tan, District 3, HCMC',
      phone: '+84 28 8765 4321',
      description: 'Cozy neighbourhood cafe focusing on specialty coffee and brunch.',
      amenities: ['wifi', 'cash', 'delivery', 'restroom'],
      images: {
        menu: ['https://placehold.co/400x300?text=menu2'],
        space: ['https://placehold.co/800x600?text=space2'],
        dishes: ['https://placehold.co/600x400?text=dish2'],
      },
      posterReview: { rating: 4, text: 'Great coffee and quiet atmosphere.' },
    },
  },
  {
    id: 'cand-1005',
    name: 'Canal View Brunch Hub',
    summary: 'Up spot pending verification for duplicate check.',
    source: 'Community submission',
    submittedAt: 'May 25, 2026 10:45 PM',
    submittedBy: 'hoangvu',
    status: 'rejected',
    placeDetails: {
      name: 'Canal View Brunch Hub',
      address: '7 Nguyen Thi Minh Khai, District 1, HCMC',
      phone: '+84 28 5656 7878',
      description: 'Brunch concept with riverside seating and fresh pastries.',
      amenities: ['wifi', 'delivery', 'restroom', 'outdoor'],
      images: {
        menu: ['https://placehold.co/400x300?text=menu5'],
        space: ['https://placehold.co/800x600?text=space5'],
        dishes: ['https://placehold.co/600x400?text=dish5'],
      },
      posterReview: { rating: 3, text: 'Nice location but a bit crowded.' },
    },
  },
  {
    id: 'cand-1006',
    name: 'Pho & Chill Alley',
    summary: 'Fresh up spot uploaded with menu and storefront images.',
    source: 'Community submission',
    submittedAt: 'May 25, 2026 12:10 PM',
    submittedBy: 'traveler_lee',
    status: 'pending',
    placeDetails: {
      name: 'Pho & Chill Alley',
      address: '204 Pasteur, District 3, HCMC',
      phone: '+84 28 4444 3333',
      description: 'Casual pho spot popular with students and office workers.',
      amenities: ['wifi', 'cash', 'delivery', 'restroom'],
      images: {
        menu: ['https://placehold.co/400x300?text=menu6'],
        space: ['https://placehold.co/800x600?text=space6'],
        dishes: ['https://placehold.co/600x400?text=dish6'],
      },
      posterReview: { rating: 5, text: 'One of my favorite quick lunch spots.' },
    },
  },
];

export const mockModerationRequests = MOCK_PENDING_CANDIDATES;

export function getModerationStats() {
  return {
    total: MOCK_PENDING_CANDIDATES.length,
    pending: MOCK_PENDING_CANDIDATES.filter((request) => request.status === 'pending').length,
    approved: MOCK_PENDING_CANDIDATES.filter((request) => request.status === 'approved').length,
  };
}

const delay = (milliseconds: number) => new Promise((resolve) => setTimeout(resolve, milliseconds));

export async function loadPendingCandidates(simulateError = false) {
  await delay(250);

  if (simulateError) {
    throw new Error('Unable to load moderation queue.');
  }

  return MOCK_PENDING_CANDIDATES;
}