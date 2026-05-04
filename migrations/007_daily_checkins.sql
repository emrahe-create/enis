CREATE TABLE IF NOT EXISTS daily_checkins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mood TEXT NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_on DATE NOT NULL DEFAULT CURRENT_DATE,
  UNIQUE (user_id, created_on)
);

CREATE INDEX IF NOT EXISTS idx_daily_checkins_user_created
  ON daily_checkins(user_id, created_at DESC);
