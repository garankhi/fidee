/**
 * Geo utilities: Haversine distance, geohash encoding, Vietnamese name normalization.
 */

const EARTH_RADIUS_METERS = 6_371_000;

/** Haversine distance between two coordinates in meters. */
export function haversineDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return EARTH_RADIUS_METERS * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ─── Geohash ────────────────────────────────────────────────────

const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/** Encode lat/lng to a geohash string of given precision (default 4 ≈ 20km cell). */
export function encodeGeohash(lat: number, lng: number, precision = 4): string {
  let minLat = -90,
    maxLat = 90,
    minLng = -180,
    maxLng = 180;
  let hash = '';
  let bit = 0;
  let ch = 0;
  let isLng = true;

  while (hash.length < precision) {
    if (isLng) {
      const mid = (minLng + maxLng) / 2;
      if (lng >= mid) {
        ch |= 1 << (4 - bit);
        minLng = mid;
      } else {
        maxLng = mid;
      }
    } else {
      const mid = (minLat + maxLat) / 2;
      if (lat >= mid) {
        ch |= 1 << (4 - bit);
        minLat = mid;
      } else {
        maxLat = mid;
      }
    }
    isLng = !isLng;
    bit++;
    if (bit === 5) {
      hash += BASE32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return hash;
}

/** Get the 8 neighboring geohash cells + the center cell itself. */
export function geohashNeighbors(hash: string): string[] {
  if (!hash) return [];
  const { lat, lng, latErr, lngErr } = decodeGeohash(hash);
  const precision = hash.length;

  const neighbors: string[] = [hash];
  const offsets = [
    [-1, -1], [-1, 0], [-1, 1],
    [0, -1],           [0, 1],
    [1, -1],  [1, 0],  [1, 1],
  ];

  for (const [dLat, dLng] of offsets) {
    const nLat = lat + dLat * latErr * 2;
    const nLng = lng + dLng * lngErr * 2;
    if (nLat >= -90 && nLat <= 90 && nLng >= -180 && nLng <= 180) {
      neighbors.push(encodeGeohash(nLat, nLng, precision));
    }
  }

  return [...new Set(neighbors)];
}

function decodeGeohash(hash: string): { lat: number; lng: number; latErr: number; lngErr: number } {
  let minLat = -90,
    maxLat = 90,
    minLng = -180,
    maxLng = 180;
  let isLng = true;

  for (const c of hash) {
    const idx = BASE32.indexOf(c);
    for (let bit = 4; bit >= 0; bit--) {
      if (isLng) {
        const mid = (minLng + maxLng) / 2;
        if (idx & (1 << bit)) {
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        const mid = (minLat + maxLat) / 2;
        if (idx & (1 << bit)) {
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }
      isLng = !isLng;
    }
  }

  return {
    lat: (minLat + maxLat) / 2,
    lng: (minLng + maxLng) / 2,
    latErr: (maxLat - minLat) / 2,
    lngErr: (maxLng - minLng) / 2,
  };
}

// ─── Name normalization ─────────────────────────────────────────

const DIACRITICS_MAP: Record<string, string> = {
  à: 'a', á: 'a', ả: 'a', ã: 'a', ạ: 'a',
  ă: 'a', ằ: 'a', ắ: 'a', ẳ: 'a', ẵ: 'a', ặ: 'a',
  â: 'a', ầ: 'a', ấ: 'a', ẩ: 'a', ẫ: 'a', ậ: 'a',
  è: 'e', é: 'e', ẻ: 'e', ẽ: 'e', ẹ: 'e',
  ê: 'e', ề: 'e', ế: 'e', ể: 'e', ễ: 'e', ệ: 'e',
  ì: 'i', í: 'i', ỉ: 'i', ĩ: 'i', ị: 'i',
  ò: 'o', ó: 'o', ỏ: 'o', õ: 'o', ọ: 'o',
  ô: 'o', ồ: 'o', ố: 'o', ổ: 'o', ỗ: 'o', ộ: 'o',
  ơ: 'o', ờ: 'o', ớ: 'o', ở: 'o', ỡ: 'o', ợ: 'o',
  ù: 'u', ú: 'u', ủ: 'u', ũ: 'u', ụ: 'u',
  ư: 'u', ừ: 'u', ứ: 'u', ử: 'u', ữ: 'u', ự: 'u',
  ỳ: 'y', ý: 'y', ỷ: 'y', ỹ: 'y', ỵ: 'y',
  đ: 'd',
};

/** Remove Vietnamese diacritics from a string. */
export function removeDiacritics(str: string): string {
  return str
    .split('')
    .map((c) => DIACRITICS_MAP[c] ?? DIACRITICS_MAP[c.toLowerCase()]?.toUpperCase() ?? c)
    .join('');
}

/** Normalize a place name for duplicate comparison: lowercase, remove diacritics, collapse whitespace. */
export function normalizeName(name: string): string {
  return removeDiacritics(name).toLowerCase().replace(/\s+/g, ' ').trim();
}

/** Simple Levenshtein distance for fuzzy matching. */
export function levenshteinDistance(a: string, b: string): number {
  const m = a.length;
  const n = b.length;
  const dp: number[][] = Array.from({ length: m + 1 }, () => Array(n + 1).fill(0) as number[]);

  for (let i = 0; i <= m; i++) dp[i][0] = i;
  for (let j = 0; j <= n; j++) dp[0][j] = j;

  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      dp[i][j] =
        a[i - 1] === b[j - 1]
          ? dp[i - 1][j - 1]
          : 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
    }
  }
  return dp[m][n];
}
