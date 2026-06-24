-- ============================================================================
-- 015_vector_768
-- Migrate embedding column from VECTOR(1536) to VECTOR(768) for Gemini
-- gemini-embedding-001 model with outputDimensionality=768.
-- ============================================================================

-- Step 1: Drop old column (currently NULL for all rows, no data loss)
ALTER TABLE places DROP COLUMN IF EXISTS embedding;

-- Step 2: Recreate with correct dimensions for Gemini gemini-embedding-001
ALTER TABLE places ADD COLUMN embedding VECTOR(768);

-- Step 3: Create HNSW index for cosine similarity search
-- HNSW advantages over IVFFlat:
--   - No training data needed (works well even with few rows)
--   - Auto-updates on INSERT (no rebuild required)
--   - Better recall at small-to-medium scale (< 1M rows)
CREATE INDEX idx_places_embedding ON places
  USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);
