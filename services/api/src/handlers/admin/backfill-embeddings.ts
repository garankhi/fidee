import { APIGatewayProxyResult } from 'aws-lambda';
import { getPool } from '../../db/client';
import { EmbeddingService } from '../../services/embedding-service';

/**
 * Backfill Embeddings Lambda
 *
 * Invoke manually to generate embeddings for all places that don't have one yet.
 * Usage: aws lambda invoke --function-name fidee-dev-backfill-embeddings response.json
 */
export async function handler(): Promise<APIGatewayProxyResult> {
  const pool = await getPool();
  const embeddingService = new EmbeddingService();

  let processed = 0;
  let failed = 0;
  const errors: { placeId: string; error: string }[] = [];

  try {
    // 1. Fetch all places without embeddings
    const result = await pool.query(
      'SELECT id, name, category, description, metadata FROM places WHERE embedding IS NULL',
    );
    const places = result.rows;

    console.log(`Found ${places.length} places without embeddings`);

    if (places.length === 0) {
      return {
        statusCode: 200,
        body: JSON.stringify({
          status: 'ok',
          message: 'All places already have embeddings',
          processed: 0,
          failed: 0,
        }),
      };
    }

    // 2. Process in batches of 10 (conservative to avoid rate limits)
    const batchSize = 10;
    for (let i = 0; i < places.length; i += batchSize) {
      const batch = places.slice(i, i + batchSize);

      const promises = batch.map(async (place) => {
        try {
          const text = embeddingService.buildPlaceText({
            name: place.name,
            category: place.category,
            description: place.description,
            metadata: typeof place.metadata === 'string'
              ? JSON.parse(place.metadata)
              : place.metadata,
          });

          const vector = await embeddingService.embedText(text);

          await pool.query(
            'UPDATE places SET embedding = $1 WHERE id = $2',
            [`[${vector.join(',')}]`, place.id],
          );

          processed++;
          console.log(`✅ Embedded: ${place.name} (${place.id})`);
        } catch (err) {
          failed++;
          const msg = err instanceof Error ? err.message : String(err);
          errors.push({ placeId: place.id, error: msg });
          console.error(`❌ Failed: ${place.name} (${place.id}): ${msg}`);
        }
      });

      await Promise.all(promises);

      // Rate limit pause between batches
      if (i + batchSize < places.length) {
        await new Promise((resolve) => setTimeout(resolve, 500));
      }
    }

    console.log(`Backfill complete: ${processed} processed, ${failed} failed`);

    return {
      statusCode: 200,
      body: JSON.stringify({
        status: 'ok',
        total: places.length,
        processed,
        failed,
        errors: errors.length > 0 ? errors : undefined,
      }),
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('Backfill failed:', message);
    return {
      statusCode: 500,
      body: JSON.stringify({ status: 'error', error: message, processed, failed }),
    };
  }
}
