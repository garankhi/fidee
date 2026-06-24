-- ============================================================================
-- 014_user_chat
-- Realtime direct user chat source-of-truth tables.
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_chat_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL DEFAULT 'DIRECT' CHECK (type IN ('DIRECT')),
  direct_key TEXT UNIQUE,
  created_by TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  last_message_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_chat_participants (
  conversation_id UUID NOT NULL REFERENCES user_chat_conversations(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_message_id UUID,
  muted_until TIMESTAMPTZ,
  archived_at TIMESTAMPTZ,
  PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS user_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES user_chat_conversations(id) ON DELETE CASCADE,
  sender_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_message_id TEXT NOT NULL,
  body TEXT NOT NULL CHECK (length(body) > 0 AND length(body) <= 2000),
  status TEXT NOT NULL DEFAULT 'SENT' CHECK (status IN ('SENT', 'DELETED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  edited_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  UNIQUE (sender_id, client_message_id)
);

ALTER TABLE user_chat_conversations
  ADD CONSTRAINT fk_user_chat_last_message
  FOREIGN KEY (last_message_id) REFERENCES user_chat_messages(id) ON DELETE SET NULL;

ALTER TABLE user_chat_participants
  ADD CONSTRAINT fk_user_chat_last_read_message
  FOREIGN KEY (last_read_message_id) REFERENCES user_chat_messages(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS user_chat_message_receipts (
  message_id UUID NOT NULL REFERENCES user_chat_messages(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_chat_participants_inbox
  ON user_chat_participants (user_id, archived_at, conversation_id);

CREATE INDEX IF NOT EXISTS idx_user_chat_messages_conversation
  ON user_chat_messages (conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_chat_conversations_updated
  ON user_chat_conversations (updated_at DESC);

DROP TRIGGER IF EXISTS trg_user_chat_conversations_updated ON user_chat_conversations;
CREATE TRIGGER trg_user_chat_conversations_updated
  BEFORE UPDATE ON user_chat_conversations
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
