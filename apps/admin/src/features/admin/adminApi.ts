import axios from 'axios';
import type { ModerationRequest, Place, User } from './adminData';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';

// Cấu hình instance Axios cao cấp
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptor tự động tiêm JWT Token của Admin vào mọi yêu cầu gửi đi
api.interceptors.request.use((config) => {
  const token = typeof window !== 'undefined' && window.localStorage
    ? window.localStorage.getItem('admin_token')
    : null;
  if (token) {
    config.headers.Authorization = token;
  }
  return config;
});

/**
 * Fetch all users from the backend API.
 */
export async function fetchUsers(): Promise<User[]> {
  const response = await api.get<User[]>('/admin/users');
  return response.data;
}

/**
 * Update user details in the backend API.
 */
export async function updateUserData(userId: string, data: Partial<User>): Promise<User> {
  const response = await api.put<User>(`/admin/users/${userId}`, data);
  return response.data;
}

type ApiEnvelope<T> = {
  status: string;
  data: T;
};

type AdminCandidateRow = {
  id: string;
  name: string;
  category?: string;
  address?: string | null;
  media_id?: string | null;
  open_time?: string | null;
  close_time?: string | null;
  price_min?: number | null;
  price_max?: number | null;
  phone_number?: string | null;
  description?: string | null;
  metadata?: string | Record<string, unknown> | null;
  status: string;
  rejection_reason?: string | null;
  created_at: string;
  created_by_name?: string | null;
  created_by_username?: string | null;
  coordinates?: { lat: number; lng: number };
};

type CandidateDetailResponse = {
  candidate: AdminCandidateRow;
  gps_proof: GpsProofRow[];
  duplicate_hints: Array<Record<string, unknown>>;
};

type GpsProofRow = {
  gps_lat?: number | string | null;
  gps_lng?: number | string | null;
  gps_accuracy?: number | string | null;
  media_id?: string | null;
  mediaId?: string | null;
  created_at?: string | null;
  mediaUrl?: string | null;
};

export type AdminPlacePayload = {
  name: string;
  category: string;
  address?: string;
  coordinates: { lat: number; lng: number };
  visibility?: 'PUBLIC' | 'FRIENDS' | 'PRIVATE';
  status?: 'APPROVED' | 'PENDING_REVIEW' | 'HIDDEN' | 'DELETED';
  openTime?: string;
  closeTime?: string;
  priceMin?: number | null;
  priceMax?: number | null;
  phoneNumber?: string;
  description?: string;
};

function toUiStatus(status: string): ModerationRequest['status'] {
  if (status === 'APPROVED') return 'approved';
  if (status === 'REJECTED') return 'rejected';
  if (status === 'NEEDS_MORE_INFO') return 'needs_more_info';
  return 'pending';
}

function formatDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;

  return date.toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

function parseMetadata(value: AdminCandidateRow['metadata']): Record<string, unknown> {
  if (!value) return {};
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value) as unknown;
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
        ? parsed as Record<string, unknown>
        : {};
    } catch {
      return {};
    }
  }
  return value;
}

function normalizeStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === 'string' && item.trim().length > 0);
}

function mediaUrl(mediaIdOrUrl: string | null | undefined): string | null {
  const mediaId = mediaIdOrUrl?.trim();
  if (!mediaId) return null;
  if (/^https?:\/\//i.test(mediaId)) return mediaId;

  const encodedMediaId = encodeURIComponent(mediaId);
  try {
    return new URL(`/media/${encodedMediaId}`, API_BASE_URL).toString();
  } catch {
    return `/media/${encodedMediaId}`;
  }
}

function mediaUrls(...values: unknown[]): string[] {
  return values
    .flatMap(normalizeStringList)
    .map(mediaUrl)
    .filter((url): url is string => Boolean(url));
}

function mapCandidate(row: AdminCandidateRow): ModerationRequest {
  const submittedBy = row.created_by_username || row.created_by_name || 'unknown-user';
  const metadata = parseMetadata(row.metadata);
  const amenities = Array.isArray(metadata.services)
    ? (metadata.services as string[])
    : Array.isArray(metadata.vibes)
      ? (metadata.vibes as string[])
      : [];
  const spaceImages = mediaUrls(
    row.media_id ? [row.media_id] : [],
    metadata.media_ids,
    metadata.mediaIds,
    metadata.space_ids,
    metadata.spaceIds,
    metadata.photo_ids,
    metadata.photoIds,
  );
  const menuImages = mediaUrls(metadata.menu_ids, metadata.menuIds);
  const dishImages = mediaUrls(metadata.dish_ids, metadata.dishIds, metadata.dishes_ids, metadata.dishesIds);
  const images = {
    ...(menuImages.length ? { menu: menuImages } : {}),
    ...(spaceImages.length ? { space: spaceImages } : {}),
    ...(dishImages.length ? { dishes: dishImages } : {}),
  };

  return {
    id: row.id,
    name: row.name,
    type: 'up-spots',
    submittedAt: formatDate(row.created_at),
    submittedBy,
    status: toUiStatus(row.status),
    summary: row.rejection_reason || row.description || 'New place submission awaiting review.',
    source: 'Community submission',
    placeDetails: {
      name: row.name,
      address: row.address || 'No address provided',
      phone: row.phone_number || '',
      description: row.description || '',
      amenities,
    },
    images: Object.keys(images).length ? images : undefined,
  };
}

function mapPlace(row: any): Place {
  return {
    id: row.id,
    name: row.name,
    category: row.category || 'other',
    address: row.address || '',
    phone: row.phone_number || '',
    description: row.description || '',
    amenities: Array.isArray(row.metadata?.services) ? row.metadata.services : [],
    rating: Number(row.avg_rating || 0),
    reviews: Number(row.rating_count || 0),
    createdAt: row.created_at ? formatDate(row.created_at) : '',
    createdBy: row.created_by_username || row.created_by_name || row.created_by || 'system',
    status: row.status || 'APPROVED',
    visibility: row.visibility || 'PUBLIC',
    openTime: row.open_time || '',
    closeTime: row.close_time || '',
    priceMin: row.price_min ?? null,
    priceMax: row.price_max ?? null,
    coordinates: row.coordinates,
  };
}

export async function fetchModerationRequests(status?: string): Promise<ModerationRequest[]> {
  const response = await api.get<ApiEnvelope<AdminCandidateRow[]>>('/admin/places/pending', {
    params: status ? { status } : undefined,
  });
  return response.data.data.map(mapCandidate);
}

export async function fetchCandidateDetail(candidateId: string): Promise<{
  request: ModerationRequest;
  gpsProof: GpsProofRow[];
  duplicateHints: Array<Record<string, unknown>>;
}> {
  const response = await api.get<ApiEnvelope<CandidateDetailResponse>>(
    `/admin/places/candidates/${candidateId}`,
  );
  return {
    request: mapCandidate(response.data.data.candidate),
    gpsProof: response.data.data.gps_proof.map((proof) => ({
      ...proof,
      mediaUrl: mediaUrl(proof.media_id || proof.mediaId),
    })),
    duplicateHints: response.data.data.duplicate_hints,
  };
}

export async function approveCandidate(candidateId: string): Promise<void> {
  await api.post(`/admin/places/candidates/${candidateId}/approve`, {});
}

export async function rejectCandidate(candidateId: string, reason: string): Promise<void> {
  await api.post(`/admin/places/candidates/${candidateId}/reject`, { reason });
}

export async function fetchPlaces(): Promise<Place[]> {
  const response = await api.get<ApiEnvelope<any[]>>('/admin/places');
  return response.data.data.map(mapPlace);
}

export async function createPlace(data: AdminPlacePayload): Promise<Place> {
  const response = await api.post<ApiEnvelope<any>>('/admin/places', data);
  return mapPlace(response.data.data);
}

export async function updatePlace(placeId: string, data: Partial<AdminPlacePayload>): Promise<Place> {
  const response = await api.put<ApiEnvelope<any>>(`/admin/places/${placeId}`, data);
  return mapPlace(response.data.data);
}

export async function deletePlace(placeId: string): Promise<void> {
  await api.delete(`/admin/places/${placeId}`);
}
