export type ModerationStatus = 'pending' | 'approved' | 'rejected' | 'needs_more_info';
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
  fullName: string;
  email: string;
  phone: string;
  joinedDate: string;
  contributions: number;
  status: 'active' | 'inactive';
  license: 'Free' | 'Basic' | 'Pro' | 'Enterprise';
  role: 'User' | 'Moderator' | 'Admin';
}

export interface Place {
  id: string;
  name: string;
  category?: string;
  address: string;
  phone: string;
  description: string;
  amenities: string[];
  rating: number;
  reviews: number;
  createdAt: string;
  createdBy: string;
  status?: 'APPROVED' | 'PENDING_REVIEW' | 'HIDDEN' | 'DELETED';
  visibility?: 'PUBLIC' | 'FRIENDS' | 'PRIVATE';
  openTime?: string;
  closeTime?: string;
  priceMin?: number | null;
  priceMax?: number | null;
  coordinates?: {
    lat: number;
    lng: number;
  };
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
