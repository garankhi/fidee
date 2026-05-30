import { describe, it, expect } from 'vitest';
import {
  haversineDistance,
  encodeGeohash,
  geohashNeighbors,
  removeDiacritics,
  normalizeName,
  levenshteinDistance,
} from './geo';

describe('haversineDistance', () => {
  it('returns 0 for same point', () => {
    expect(haversineDistance(10.77, 106.70, 10.77, 106.70)).toBe(0);
  });

  it('calculates distance between Bitexco and Ben Thanh (~550m)', () => {
    const d = haversineDistance(10.7716, 106.7042, 10.7726, 106.6980);
    expect(d).toBeGreaterThan(500);
    expect(d).toBeLessThan(700);
  });

  it('calculates distance between two nearby points within 100m', () => {
    const d = haversineDistance(10.7716, 106.7042, 10.7720, 106.7045);
    expect(d).toBeLessThan(100);
  });
});

describe('encodeGeohash', () => {
  it('encodes HCMC coordinates to expected geohash', () => {
    const hash = encodeGeohash(10.7716, 106.7042, 4);
    expect(hash).toHaveLength(4);
    expect(hash).toBe('w3gv');
  });

  it('encodes with higher precision', () => {
    const hash = encodeGeohash(10.7716, 106.7042, 6);
    expect(hash).toHaveLength(6);
  });

  it('nearby points share geohash prefix', () => {
    const h1 = encodeGeohash(10.7716, 106.7042, 4);
    const h2 = encodeGeohash(10.7720, 106.7045, 4);
    expect(h1).toBe(h2);
  });
});

describe('geohashNeighbors', () => {
  it('returns 9 cells (center + 8 neighbors)', () => {
    const neighbors = geohashNeighbors('w3gv');
    expect(neighbors.length).toBeGreaterThanOrEqual(9);
  });

  it('includes the center hash', () => {
    const neighbors = geohashNeighbors('w3gv');
    expect(neighbors).toContain('w3gv');
  });

  it('returns empty for empty hash', () => {
    expect(geohashNeighbors('')).toEqual([]);
  });
});

describe('removeDiacritics', () => {
  it('removes Vietnamese diacritics', () => {
    expect(removeDiacritics('Quán Cà Phê Bình Minh')).toBe('Quan Ca Phe Binh Minh');
  });

  it('handles đ', () => {
    expect(removeDiacritics('Đà Nẵng')).toBe('Da Nang');
  });

  it('passes through ASCII', () => {
    expect(removeDiacritics('Hello World')).toBe('Hello World');
  });
});

describe('normalizeName', () => {
  it('normalizes Vietnamese name', () => {
    expect(normalizeName('Quán Cà Phê Bình Minh')).toBe('quan ca phe binh minh');
  });

  it('collapses whitespace', () => {
    expect(normalizeName('  Cafe   ABC  ')).toBe('cafe abc');
  });

  it('handles mixed case + diacritics', () => {
    expect(normalizeName('NHÀ HÀNG PHỞ BÒ')).toBe('nha hang pho bo');
  });
});

describe('levenshteinDistance', () => {
  it('returns 0 for identical strings', () => {
    expect(levenshteinDistance('cafe abc', 'cafe abc')).toBe(0);
  });

  it('returns 1 for single char difference', () => {
    expect(levenshteinDistance('cafe', 'cafee')).toBe(1);
  });

  it('detects similar names within threshold', () => {
    const d = levenshteinDistance('quan ca phe binh minh', 'quan cafe binh minh');
    expect(d).toBeLessThanOrEqual(3);
  });
});
