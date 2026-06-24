import { GeminiRotator } from './gemini-rotator';

export interface PlaceEmbeddingInput {
  name: string;
  category: string;
  description?: string | null;
  metadata?: Record<string, unknown> | null;
}

/**
 * Embedding Service — Gemini text-embedding-004 (768 dimensions)
 *
 * Tách biệt hoàn toàn với LLM Chat (gemini-2.5-flash).
 * Dùng riêng cho việc sinh vector embedding phục vụ Vector Search.
 */
export class EmbeddingService {
  private rotator: GeminiRotator;
  private model: string;

  constructor() {
    this.rotator = new GeminiRotator();
    this.model = process.env.GEMINI_EMBEDDING_MODEL || 'gemini-embedding-001';
  }

  /**
   * Build a single text string from place data, optimized for embedding.
   * Combines name, category, description, vibes, and services into one string.
   */
  buildPlaceText(place: PlaceEmbeddingInput): string {
    const parts: string[] = [];

    parts.push(place.name);
    parts.push(`Loại: ${place.category}`);

    if (place.description) {
      parts.push(place.description);
    }

    if (place.metadata && typeof place.metadata === 'object') {
      const meta = place.metadata as Record<string, unknown>;
      if (Array.isArray(meta.vibes) && meta.vibes.length > 0) {
        parts.push(`Phong cách: ${meta.vibes.join(', ')}`);
      }
      if (Array.isArray(meta.services) && meta.services.length > 0) {
        parts.push(`Dịch vụ: ${meta.services.join(', ')}`);
      }
    }

    return parts.join('. ');
  }

  /**
   * Embed a single text string into a 768-dimensional vector.
   */
  async embedText(text: string): Promise<number[]> {
    const response = await this.rotator.executeWithRetry(async (ai) => {
      return ai.models.embedContent({
        model: this.model,
        contents: text,
        config: { outputDimensionality: 768 },
      });
    });

    if (!response.embeddings || response.embeddings.length === 0) {
      throw new Error('Gemini embedding returned empty result');
    }

    const values = response.embeddings[0].values;
    if (!values || values.length === 0) {
      throw new Error('Gemini embedding returned empty values');
    }

    return values;
  }

  /**
   * Embed multiple texts in batch.
   * Gemini embedContent supports batch via multiple contents.
   */
  async embedBatch(texts: string[]): Promise<number[][]> {
    const results: number[][] = [];

    // Process in chunks of 100 to avoid rate limits
    const chunkSize = 100;
    for (let i = 0; i < texts.length; i += chunkSize) {
      const chunk = texts.slice(i, i + chunkSize);

      // Embed each text individually (Gemini embedContent doesn't support true batch)
      const promises = chunk.map((text) => this.embedText(text));
      const chunkResults = await Promise.all(promises);
      results.push(...chunkResults);

      // Small delay between chunks to avoid rate limiting
      if (i + chunkSize < texts.length) {
        await new Promise((resolve) => setTimeout(resolve, 200));
      }
    }

    return results;
  }
}
