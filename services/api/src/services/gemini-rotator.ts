import { GoogleGenAI } from '@google/genai';

/**
 * GeminiRotator handles API key rotation and retry logic for Google Gen AI.
 * It expects a GEMINI_API_KEYS environment variable containing a comma-separated list of keys.
 */
export class GeminiRotator {
  private keys: string[];
  private currentIndex: number = 0;

  constructor() {
    const keysEnv = process.env.GEMINI_API_KEYS || process.env.GEMINI_API_KEY || '';
    // Split by comma, remove whitespace, and filter out empty strings
    this.keys = keysEnv.split(',').map(k => k.trim()).filter(k => k.length > 0);

    if (this.keys.length === 0) {
      console.warn('⚠️ No Gemini API keys found in environment variables (GEMINI_API_KEYS). API calls will likely fail.');
    }
  }

  /**
   * Get the active GoogleGenAI instance for the current key.
   */
  public get client(): GoogleGenAI {
    if (this.keys.length === 0) {
      return new GoogleGenAI({ apiKey: 'missing-key' });
    }
    return new GoogleGenAI({ apiKey: this.keys[this.currentIndex] });
  }

  /**
   * Execute a GoogleGenAI operation with automatic key rotation on quota/rate-limit errors.
   */
  public async executeWithRetry<T>(operation: (ai: GoogleGenAI) => Promise<T>): Promise<T> {
    const maxAttempts = Math.max(1, this.keys.length);
    let attempts = 0;
    let lastError: any;

    while (attempts < maxAttempts) {
      try {
        const ai = this.client;
        return await operation(ai);
      } catch (error: any) {
        lastError = error;
        attempts++;

        const isRateLimitOrQuota = this.isRetryableError(error);

        if (isRateLimitOrQuota && this.keys.length > 1) {
          console.warn(`⚠️ Gemini API Key [Index ${this.currentIndex}] failed (Rate Limit / Quota). Rotating to next key...`);
          this.rotateKey();
          
          // Small backoff before retrying with new key
          await new Promise(res => setTimeout(res, 500));
        } else {
          // If it's a structural error (e.g., bad request 400) or we only have 1 key, throw immediately
          throw error;
        }
      }
    }

    console.error('❌ All Gemini API keys exhausted or failed.');
    throw lastError;
  }

  /**
   * Advance to the next API key in the list.
   */
  private rotateKey() {
    this.currentIndex = (this.currentIndex + 1) % this.keys.length;
  }

  /**
   * Check if the error warrants a retry (e.g., 429 Too Many Requests, 503 Service Unavailable, 403 Quota Exceeded).
   */
  private isRetryableError(error: any): boolean {
    const message = (error?.message || '').toLowerCase();
    const status = error?.status || error?.response?.status;
    
    if (status === 429 || status === 503 || status === 403) return true;
    
    // Fallback: check error string
    return (
      message.includes('too many requests') ||
      message.includes('quota') ||
      message.includes('exhausted') ||
      message.includes('rate limit') ||
      message.includes('overloaded') ||
      message.includes('503')
    );
  }
}
