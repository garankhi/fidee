export const MAX_IMAGE_UPLOAD_BYTES = 5 * 1024 * 1024;
export const MAX_VIDEO_UPLOAD_BYTES = 20 * 1024 * 1024;
export const MAX_VIDEO_DURATION_MS = 3000;
export const MAX_UPLOAD_BYTES = MAX_IMAGE_UPLOAD_BYTES;
export const UPLOAD_EXPIRY_SECONDS = 300;
export const UPLOAD_PREFIX = 'uploads/';
export const MEDIA_STATUS_PENDING_MODERATION = 'PENDING_MODERATION';

export const PHOTO_SOURCES = ['IN_APP_CAMERA', 'EXIF_GALLERY'] as const;
export const VIDEO_SOURCES = ['IN_APP_CAMERA_VIDEO', 'EXIF_GALLERY_VIDEO'] as const;
export const MEDIA_SOURCES = [...PHOTO_SOURCES, ...VIDEO_SOURCES] as const;

export type PhotoSource = (typeof PHOTO_SOURCES)[number];
export type VideoSource = (typeof VIDEO_SOURCES)[number];
export type MediaSource = (typeof MEDIA_SOURCES)[number];
export type MediaType = 'IMAGE' | 'VIDEO';

export const SUPPORTED_CONTENT_TYPES = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'video/mp4': 'mp4',
  'video/quicktime': 'mov',
} as const;

export type SupportedContentType = keyof typeof SUPPORTED_CONTENT_TYPES;

export interface GpsProof {
  latitude: number;
  longitude: number;
  capturedAt?: string;
  accuracyMeters?: number;
}

export interface ValidatedUploadRequest {
  source: MediaSource;
  contentType: SupportedContentType;
  contentLength: number;
  gpsProof: GpsProof;
  mediaType: MediaType;
  durationMs?: number;
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

export function isPhotoSource(value: unknown): value is PhotoSource {
  return PHOTO_SOURCES.includes(value as PhotoSource);
}

export function isVideoSource(value: unknown): value is VideoSource {
  return VIDEO_SOURCES.includes(value as VideoSource);
}

export function isMediaSource(value: unknown): value is MediaSource {
  return MEDIA_SOURCES.includes(value as MediaSource);
}

export function isSupportedContentType(value: unknown): value is SupportedContentType {
  return typeof value === 'string' && value in SUPPORTED_CONTENT_TYPES;
}

export function isVideoContentType(contentType: SupportedContentType): boolean {
  return contentType.startsWith('video/');
}

export function mediaTypeForContentType(contentType: SupportedContentType): MediaType {
  return isVideoContentType(contentType) ? 'VIDEO' : 'IMAGE';
}

export function maxUploadBytesForContentType(contentType: SupportedContentType): number {
  return isVideoContentType(contentType) ? MAX_VIDEO_UPLOAD_BYTES : MAX_IMAGE_UPLOAD_BYTES;
}

export function extensionForContentType(contentType: SupportedContentType): string {
  return SUPPORTED_CONTENT_TYPES[contentType];
}

export function buildObjectKey(mediaId: string, contentType: SupportedContentType): string {
  return `${UPLOAD_PREFIX}${mediaId}.${extensionForContentType(contentType)}`;
}

export function validateUploadRequest(value: unknown): ValidatedUploadRequest {
  if (!isRecord(value)) {
    throw new ValidationError('Request body must be a JSON object');
  }

  const source = value.source;
  if (!isMediaSource(source)) {
    throw new ValidationError(
      'source must be IN_APP_CAMERA, EXIF_GALLERY, IN_APP_CAMERA_VIDEO, or EXIF_GALLERY_VIDEO',
    );
  }

  const contentType = value.contentType;
  if (!isSupportedContentType(contentType)) {
    throw new ValidationError(
      'contentType must be image/jpeg, image/png, image/webp, video/mp4, or video/quicktime',
    );
  }

  const mediaType = mediaTypeForContentType(contentType);
  if (mediaType === 'VIDEO' && !isVideoSource(source)) {
    throw new ValidationError('video uploads must use a video source');
  }
  if (mediaType === 'IMAGE' && !isPhotoSource(source)) {
    throw new ValidationError('image uploads must use an image source');
  }

  const contentLength = value.contentLength;
  if (typeof contentLength !== 'number' || !Number.isInteger(contentLength) || contentLength <= 0) {
    throw new ValidationError('contentLength must be a positive integer');
  }

  const maxBytes = maxUploadBytesForContentType(contentType);
  if (contentLength > maxBytes) {
    throw new ValidationError(
      mediaType === 'VIDEO'
        ? 'contentLength exceeds 20MB video limit'
        : 'contentLength exceeds 5MB image limit',
    );
  }

  let durationMs: number | undefined;
  if (mediaType === 'VIDEO') {
    const rawDurationMs = value.durationMs;
    if (
      typeof rawDurationMs !== 'number' ||
      !Number.isInteger(rawDurationMs) ||
      rawDurationMs <= 0
    ) {
      throw new ValidationError('durationMs is required for video uploads');
    }
    if (rawDurationMs > MAX_VIDEO_DURATION_MS) {
      throw new ValidationError('durationMs exceeds 3000ms video limit');
    }
    durationMs = rawDurationMs;
  }

  const gpsProof = value.gpsProof;
  if (!isRecord(gpsProof)) {
    throw new ValidationError('gpsProof is required');
  }

  const latitude = gpsProof.latitude;
  if (
    typeof latitude !== 'number' ||
    !Number.isFinite(latitude) ||
    latitude < -90 ||
    latitude > 90
  ) {
    throw new ValidationError('gpsProof.latitude must be between -90 and 90');
  }

  const longitude = gpsProof.longitude;
  if (
    typeof longitude !== 'number' ||
    !Number.isFinite(longitude) ||
    longitude < -180 ||
    longitude > 180
  ) {
    throw new ValidationError('gpsProof.longitude must be between -180 and 180');
  }

  const normalizedGpsProof: GpsProof = { latitude, longitude };

  const capturedAt = gpsProof.capturedAt;
  if (capturedAt !== undefined) {
    if (typeof capturedAt !== 'string' || capturedAt.trim().length === 0) {
      throw new ValidationError('gpsProof.capturedAt must be an ISO timestamp string');
    }
    const timestamp = Date.parse(capturedAt);
    if (Number.isNaN(timestamp)) {
      throw new ValidationError('gpsProof.capturedAt must be a valid timestamp');
    }
    normalizedGpsProof.capturedAt = capturedAt;
  }

  const accuracyMeters = gpsProof.accuracyMeters;
  if (accuracyMeters !== undefined) {
    if (
      typeof accuracyMeters !== 'number' ||
      !Number.isFinite(accuracyMeters) ||
      accuracyMeters < 0
    ) {
      throw new ValidationError('gpsProof.accuracyMeters must be a non-negative number');
    }
    normalizedGpsProof.accuracyMeters = accuracyMeters;
  }

  return {
    source,
    contentType,
    contentLength,
    gpsProof: normalizedGpsProof,
    mediaType,
    durationMs,
  };
}
