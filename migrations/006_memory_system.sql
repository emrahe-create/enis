CREATE TABLE IF NOT EXISTS user_memories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  "key" TEXT NOT NULL,
  value TEXT NOT NULL,
  importance INTEGER NOT NULL DEFAULT 2 CHECK (importance BETWEEN 1 AND 5),
  last_used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, "key")
);

CREATE INDEX IF NOT EXISTS idx_user_memories_user_id ON user_memories(user_id);
CREATE INDEX IF NOT EXISTS idx_user_memories_rank
  ON user_memories(user_id, importance DESC, last_used_at DESC NULLS LAST, updated_at DESC);

CREATE TABLE IF NOT EXISTS conversation_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conversation_messages_user_created
  ON conversation_messages(user_id, created_at DESC);
