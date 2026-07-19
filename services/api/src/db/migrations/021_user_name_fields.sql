ALTER TABLE users
  ADD COLUMN IF NOT EXISTS family_name TEXT,
  ADD COLUMN IF NOT EXISTS given_name TEXT;

UPDATE users
SET
  family_name = COALESCE(
    family_name,
    NULLIF(substring(btrim(display_name) FROM '^\S+'), '')
  ),
  given_name = COALESCE(
    given_name,
    NULLIF(
      btrim(regexp_replace(btrim(display_name), '^\S+\s*', '')),
      ''
    )
  )
WHERE (family_name IS NULL OR given_name IS NULL)
  AND NULLIF(btrim(display_name), '') IS NOT NULL;
