export type ModerationStatus = 'pending' | 'approved' | 'rejected';
export type RequestType = 'up-spots' | 'review';
export type ActivityType = 'create' | 'review' | 'approve' | 'reject' | 'flag' | 'edit' | 'delete' | 'favorite' | 'settings';

export interface ModerationRequest {
  id: string;
  name: string;
  type: RequestType;
  submittedAt: string;
  submittedBy: string;
  status: ModerationStatus;
  summary: string;
  source: string;
  placeDetails: {
    name: string;
    address: string;
    phone: string;
    description: string;
    amenities: string[];
  };
  posterReview?: {
    rating: number;
    text: string;
  };
  images?: {
    menu?: string[];
    space?: string[];
    dishes?: string[];
  };
}

export interface User {
  id: string;
  username: string;
  email: string;
  joinedDate: string;
  contributions: number;
  status: 'active' | 'inactive';
}

export interface Place {
  id: string;
  name: string;
  address: string;
  phone: string;
  description: string;
  amenities: string[];
  rating: number;
  reviews: number;
  createdAt: string;
  createdBy: string;
}

export interface ActivityLog {
  id: number;
  user: string;
  action: string;
  target: string;
  type: ActivityType;
  timestamp: string;
  icon: string;
}

export interface ReportMetric {
  label: string;
  value: number;
  trend: string;
  tone: 'neutral' | 'success' | 'warning' | 'danger';
}

export interface Payment {
  id: string;
  customer: string;
  plan: string;
  amount: string;
  status: 'paid' | 'pending' | 'failed';
  date: string;
}

export interface ContentItem {
  id: string;
  title: string;
  type: string;
  status: 'draft' | 'published' | 'needs review';
  views: number;
  createdAt: string;
  category: string;
}

export interface CategoryPerformance {
  category: string;
  places: number;
  views: number;
  avgRating: number;
}

export const mockModerationRequests: ModerationRequest[] = [
  {
    id: 'cand-1001',
    name: 'Rooftop Bar Saigon',
    type: 'up-spots',
    submittedAt: 'May 27, 2026 8:15 AM',
    submittedBy: 'nguyenminh',
    status: 'pending',
    summary: 'New place submission awaiting review.',
    source: 'Community submission',
    placeDetails: {
      name: 'Rooftop Bar Saigon',
      address: '123 Nguyen Hue, District 1, HCMC',
      phone: '+84 28 1234 5678',
      description: 'A popular rooftop bar with panoramic city views and live music.',
      amenities: ['wifi', 'cash', 'restroom', 'outdoor'],
    },
    posterReview: {
      rating: 5,
      text: 'Amazing view and great cocktails!',
    },
    images: {
      menu: ['https://placehold.co/400x300?text=menu1'],
      space: ['https://placehold.co/800x600?text=space1'],
      dishes: ['https://placehold.co/600x400?text=dish1'],
    },
  },
  {
    id: 'cand-1002',
    name: 'Saigon Sunset Coffee',
    type: 'up-spots',
    submittedAt: 'May 27, 2026 7:40 AM',
    submittedBy: 'phamlinh',
    status: 'pending',
    summary: 'New up spot submitted by community member.',
    source: 'Community submission',
    placeDetails: {
      name: 'Saigon Sunset Coffee',
      address: '12 Le Loi, District 1, HCMC',
      phone: '+84 28 1111 2222',
      description: 'Modern cafe with rooftop corner and sunset city view.',
      amenities: ['wifi', 'cash', 'restroom', 'outdoor'],
    },
    posterReview: {
      rating: 4,
      text: 'Comfy vibes and friendly staff.',
    },
    images: {
      menu: ['https://placehold.co/400x300?text=menu3'],
      space: ['https://placehold.co/800x600?text=space3'],
      dishes: ['https://placehold.co/600x400?text=dish3'],
    },
  },
  {
    id: 'cand-1003',
    name: 'Night Noodle Corner',
    type: 'up-spots',
    submittedAt: 'May 26, 2026 6:20 PM',
    submittedBy: 'foodie_sg',
    status: 'approved',
    summary: 'Up spot request with late-night opening hours.',
    source: 'Contributor edit',
    placeDetails: {
      name: 'Night Noodle Corner',
      address: '88 Tran Hung Dao, District 5, HCMC',
      phone: '+84 28 7777 9999',
      description: 'Street-style noodle spot open until midnight.',
      amenities: ['cash', 'delivery', 'outdoor'],
    },
    posterReview: {
      rating: 4,
      text: 'Great broth and quick service.',
    },
    images: {
      menu: ['https://placehold.co/400x300?text=menu4'],
      space: ['https://placehold.co/800x600?text=space4'],
      dishes: ['https://placehold.co/600x400?text=dish4'],
    },
  },
  {
    id: 'cand-1004',
    name: 'Hidden cafe in District 3',
    type: 'up-spots',
    submittedAt: 'May 26, 2026 4:05 PM',
    submittedBy: 'jane.doe',
    status: 'pending',
    summary: 'Up spot edit request includes new photos and opening hours.',
    source: 'Contributor edit',
    placeDetails: {
      name: 'Hidden cafe in District 3',
      address: '45 Vo Van Tan, District 3, HCMC',
      phone: '+84 28 8765 4321',
      description: 'Cozy neighbourhood cafe focusing on specialty coffee and brunch.',
      amenities: ['wifi', 'cash', 'delivery', 'restroom'],
    },
    posterReview: {
      rating: 4,
      text: 'Great coffee and quiet atmosphere.',
    },
    images: {
      menu: ['https://placehold.co/400x300?text=menu2'],
      space: ['https://placehold.co/800x600?text=space2'],
      dishes: ['https://placehold.co/600x400?text=dish2'],
    },
  },
  {
    id: 'cand-1005',
    name: 'Canal View Brunch Hub',
    type: 'up-spots',
    submittedAt: 'May 25, 2026 10:45 PM',
    submittedBy: 'hoangvu',
    status: 'rejected',
    summary: 'Up spot pending verification for duplicate check.',
    source: 'Community submission',
    placeDetails: {
      name: 'Canal View Brunch Hub',
      address: '7 Nguyen Thi Minh Khai, District 1, HCMC',
      phone: '+84 28 5656 7878',
      description: 'Brunch concept with riverside seating and fresh pastries.',
      amenities: ['wifi', 'delivery', 'restroom', 'outdoor'],
    },
    posterReview: {
      rating: 3,
      text: 'Nice location but a bit crowded.',
    },
    images: {
      menu: ['https://placehold.co/400x300?text=menu5'],
      space: ['https://placehold.co/800x600?text=space5'],
      dishes: ['https://placehold.co/600x400?text=dish5'],
    },
  },
  {
    id: 'cand-1006',
    name: 'Pho & Chill Alley',
    type: 'up-spots',
    submittedAt: 'May 25, 2026 12:10 PM',
    submittedBy: 'traveler_lee',
    status: 'pending',
    summary: 'Fresh up spot uploaded with menu and storefront images.',
    source: 'Community submission',
    placeDetails: {
      name: 'Pho & Chill Alley',
      address: '204 Pasteur, District 3, HCMC',
      phone: '+84 28 4444 3333',
      description: 'Casual pho spot popular with students and office workers.',
      amenities: ['wifi', 'cash', 'delivery', 'restroom'],
    },
    posterReview: {
      rating: 5,
      text: 'One of my favorite quick lunch spots.',
    },
    images: {
      menu: ['https://placehold.co/400x300?text=menu6'],
      space: ['https://placehold.co/800x600?text=space6'],
      dishes: ['https://placehold.co/600x400?text=dish6'],
    },
  },
];

export const mockUsers: User[] = [
  { id: 'user-1', username: 'nguyenminh', email: 'nguyen@example.com', joinedDate: 'Jan 15, 2024', contributions: 12, status: 'active' },
  { id: 'user-2', username: 'foodie_sg', email: 'foodie@example.com', joinedDate: 'Feb 20, 2024', contributions: 28, status: 'active' },
  { id: 'user-3', username: 'jane.doe', email: 'jane@example.com', joinedDate: 'Mar 10, 2024', contributions: 8, status: 'active' },
  { id: 'user-4', username: 'hoangvu', email: 'hoang@example.com', joinedDate: 'Mar 25, 2024', contributions: 15, status: 'inactive' },
  { id: 'user-5', username: 'traveler_lee', email: 'traveler@example.com', joinedDate: 'Apr 5, 2024', contributions: 20, status: 'active' },
];

export const mockPlaces: Place[] = [
  {
    id: 'place-1',
    name: 'Rooftop Bar Saigon',
    address: '123 Nguyen Hue, District 1, HCMC',
    phone: '+84 28 1234 5678',
    description: 'A popular rooftop bar with panoramic city views and live music.',
    amenities: ['wifi', 'cash', 'restroom', 'outdoor'],
    rating: 4.8,
    reviews: 234,
    createdAt: 'May 20, 2024',
    createdBy: 'admin',
  },
  {
    id: 'place-2',
    name: 'Banh Mi Huynh Hoa',
    address: '456 Pasteur, District 1, HCMC',
    phone: '+84 28 5678 1234',
    description: 'Traditional Vietnamese banh mi shop with authentic recipes.',
    amenities: ['wifi', 'cash'],
    rating: 4.5,
    reviews: 156,
    createdAt: 'May 10, 2024',
    createdBy: 'foodie_sg',
  },
  {
    id: 'place-3',
    name: 'Night Noodle Corner',
    address: '88 Tran Hung Dao, District 5, HCMC',
    phone: '+84 28 7777 9999',
    description: 'Late night noodle restaurant with authentic flavors.',
    amenities: ['cash', 'restroom', 'outdoor'],
    rating: 4.6,
    reviews: 189,
    createdAt: 'May 15, 2024',
    createdBy: 'foodie_sg',
  },
  {
    id: 'place-4',
    name: 'Hidden Cafe District 3',
    address: '45 Vo Van Tan, District 3, HCMC',
    phone: '+84 28 8765 4321',
    description: 'Cozy hidden cafe with vintage decor and quiet atmosphere.',
    amenities: ['wifi', 'cash', 'restroom'],
    rating: 4.7,
    reviews: 98,
    createdAt: 'May 18, 2024',
    createdBy: 'jane.doe',
  },
  {
    id: 'place-5',
    name: 'Canal View Brunch Hub',
    address: '7 Nguyen Thi Minh Khai, District 1, HCMC',
    phone: '+84 28 5656 7878',
    description: 'Waterfront brunch spot with beautiful views and pastries.',
    amenities: ['wifi', 'delivery', 'outdoor', 'parking'],
    rating: 4.2,
    reviews: 76,
    createdAt: 'May 22, 2024',
    createdBy: 'hoangvu',
  },
];

export const activityLogs: ActivityLog[] = [
  { id: 1, user: 'nguyen_minh', action: 'Submitted new place', target: 'Rooftop Bar Saigon', type: 'create', timestamp: '2 min ago', icon: '📍' },
  { id: 2, user: 'foodie_sg', action: 'Posted review', target: 'Pho Chill Alley', type: 'review', timestamp: '15 min ago', icon: '💬' },
  { id: 3, user: 'admin', action: 'Approved place submission', target: 'Night Noodle Corner', type: 'approve', timestamp: '1 hour ago', icon: '✅' },
  { id: 4, user: 'traveler_lee', action: 'Flagged content', target: 'Canal View Brunch', type: 'flag', timestamp: '2 hours ago', icon: '🚩' },
  { id: 5, user: 'admin', action: 'Deleted user account', target: 'spam_account_123', type: 'delete', timestamp: '3 hours ago', icon: '🗑️' },
  { id: 6, user: 'jane.doe', action: 'Updated place info', target: 'Hidden Cafe District 3', type: 'edit', timestamp: '4 hours ago', icon: '✏️' },
  { id: 7, user: 'hoang_vu', action: 'Submitted new review', target: 'Banh Mi Huynh Hoa', type: 'review', timestamp: '5 hours ago', icon: '💬' },
  { id: 8, user: 'admin', action: 'Rejected place submission', target: 'Spam Restaurant', type: 'reject', timestamp: '6 hours ago', icon: '⛔' },
  { id: 9, user: 'explorer_sg', action: 'Added place to favorites', target: 'Dim Sum Palace', type: 'favorite', timestamp: '7 hours ago', icon: '⭐' },
  { id: 10, user: 'admin', action: 'Updated system settings', target: 'Moderation Rules', type: 'settings', timestamp: '8 hours ago', icon: '⚙️' },
];

export const reportMetrics: ReportMetric[] = [
  { label: 'Total Reported Content', value: 287, trend: '+12%', tone: 'danger' },
  { label: 'Spam Reports', value: 156, trend: '+8%', tone: 'warning' },
  { label: 'Inappropriate Content', value: 89, trend: '+5%', tone: 'warning' },
  { label: 'Resolved', value: 214, trend: '75%', tone: 'success' },
];

export const userEngagementData = [
  { date: 'Mon', visits: 240, signups: 24, interactions: 140 },
  { date: 'Tue', visits: 280, signups: 28, interactions: 180 },
  { date: 'Wed', visits: 320, signups: 35, interactions: 200 },
  { date: 'Thu', visits: 290, signups: 30, interactions: 170 },
  { date: 'Fri', visits: 350, signups: 42, interactions: 220 },
  { date: 'Sat', visits: 380, signups: 48, interactions: 240 },
  { date: 'Sun', visits: 340, signups: 40, interactions: 210 },
];

export const categoryPerformance: CategoryPerformance[] = [
  { category: 'Vietnamese', places: 245, views: 12400, avgRating: 4.7 },
  { category: 'International', places: 189, views: 9800, avgRating: 4.5 },
  { category: 'Seafood', places: 156, views: 8900, avgRating: 4.6 },
  { category: 'Cafe', places: 234, views: 11200, avgRating: 4.4 },
  { category: 'Dessert', places: 178, views: 7600, avgRating: 4.8 },
  { category: 'Fast Food', places: 142, views: 6800, avgRating: 4.2 },
];

export const paymentRows: Payment[] = [
  { id: 'pay-001', customer: 'Rooftop Bar Saigon', plan: 'Pro', amount: '$49.00', status: 'paid', date: 'May 27, 2026' },
  { id: 'pay-002', customer: 'Hidden Cafe District 3', plan: 'Starter', amount: '$19.00', status: 'pending', date: 'May 27, 2026' },
  { id: 'pay-003', customer: 'Night Noodle Corner', plan: 'Pro', amount: '$49.00', status: 'paid', date: 'May 26, 2026' },
  { id: 'pay-004', customer: 'Canal View Brunch Hub', plan: 'Enterprise', amount: '$129.00', status: 'failed', date: 'May 25, 2026' },
];

export const contentItems: ContentItem[] = [
  { id: 'content-1', title: 'Summer Food Festival', type: 'Promotion', category: 'Festival', status: 'published', views: 1234, createdAt: '2024-05-15' },
  { id: 'content-2', title: 'New Restaurant Guide', type: 'Banner', category: 'Guide', status: 'published', views: 2456, createdAt: '2024-05-10' },
  { id: 'content-3', title: 'Best Coffee Shops 2024', type: 'News', category: 'Coffee', status: 'draft', views: 0, createdAt: '2024-05-18' },
  { id: 'content-4', title: 'Dining Week Special', type: 'Promotion', category: 'Dining', status: 'needs review', views: 3421, createdAt: '2024-04-20' },
  { id: 'content-5', title: 'User Safety Tips', type: 'News', category: 'Safety', status: 'published', views: 892, createdAt: '2024-05-12' },
  { id: 'content-6', title: 'April Highlights', type: 'Banner', category: 'April', status: 'needs review', views: 5234, createdAt: '2024-04-01' },
];

export const settingsSections = [
  {
    title: 'General',
    items: ['Branding', 'Timezone', 'Localization'],
  },
  {
    title: 'Moderation',
    items: ['Auto-approve rules', 'Flag thresholds', 'Review SLA'],
  },
  {
    title: 'Notifications',
    items: ['Email alerts', 'Slack integration', 'Digest schedule'],
  },
];

export function getModerationStats() {
  return {
    total: mockModerationRequests.length,
    pending: mockModerationRequests.filter((request) => request.status === 'pending').length,
    approved: mockModerationRequests.filter((request) => request.status === 'approved').length,
    rejected: mockModerationRequests.filter((request) => request.status === 'rejected').length,
  };
}

export function getDashboardStats() {
  return {
    places: mockPlaces.length,
    activeUsers: mockUsers.filter((user) => user.status === 'active').length,
    reviews: mockPlaces.reduce((sum, place) => sum + place.reviews, 0),
    pending: getModerationStats().pending,
  };
}

export function getRecentActivity() {
  return activityLogs.slice(0, 5);
}