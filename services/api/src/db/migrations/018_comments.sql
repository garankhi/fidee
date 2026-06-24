CREATE TABLE comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_type TEXT NOT NULL CHECK (target_type IN ('CANDIDATE', 'CHECKIN')),
    target_id UUID NOT NULL,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    reply_to_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    content TEXT NOT NULL CHECK (length(content) BETWEEN 1 AND 1000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_comments_target ON comments(target_type, target_id, created_at DESC);
CREATE INDEX idx_comments_parent ON comments(parent_id, created_at ASC);
CREATE INDEX idx_comments_user ON comments(user_id, created_at DESC);
CREATE INDEX idx_comments_reply_to_user ON comments(reply_to_user_id, created_at DESC)
  WHERE reply_to_user_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_comments_updated ON comments;
CREATE TRIGGER trg_comments_updated
  BEFORE UPDATE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
