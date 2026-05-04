CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT NOT NULL UNIQUE,
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  email_verified_at TIMESTAMPTZ,
  email_verification_token_hash TEXT,
  email_verification_sent_at TIMESTAMPTZ,
  password_hash TEXT NOT NULL,
  display_name TEXT,
  full_name TEXT,
  birth_year INTEGER,
  gender TEXT,
  city TEXT,
  occupation TEXT,
  relationship_status TEXT,
  sleep_quality TEXT,
  main_goal TEXT,
  preferred_avatar TEXT,
  avatar_name TEXT,
  avatar_character_id TEXT,
  avatar_character_name TEXT,
  avatar_voice_style TEXT,
  avatar_visual_style TEXT,
  avatar_personality_style TEXT,
  notification_consent BOOLEAN NOT NULL DEFAULT FALSE,
  marketing_consent BOOLEAN NOT NULL DEFAULT FALSE,
  role TEXT NOT NULL DEFAULT 'user',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_consents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_type TEXT NOT NULL,
  version TEXT NOT NULL,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT
);

CREATE INDEX IF NOT EXISTS idx_user_consents_user_type
  ON user_consents(user_id, consent_type, accepted_at DESC);

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan TEXT NOT NULL DEFAULT 'free',
  status TEXT NOT NULL DEFAULT 'active',
  trial_started_at TIMESTAMPTZ,
  trial_ends_at TIMESTAMPTZ,
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  current_period_ends_at TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN NOT NULL DEFAULT FALSE,
  canceled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS subscription_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  provider TEXT NOT NULL,
  external_event_id TEXT,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (provider, external_event_id)
);

CREATE TABLE IF NOT EXISTS avatars (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  tier TEXT NOT NULL DEFAULT 'basic',
  style TEXT NOT NULL DEFAULT 'calm',
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT 'Support chat',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS emotion_analyses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source TEXT NOT NULL,
  source_id UUID,
  primary_emotion TEXT NOT NULL,
  sentiment_score NUMERIC(4, 3) NOT NULL,
  intensity NUMERIC(4, 3) NOT NULL,
  labels JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wellness_entries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tool_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS experts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  display_name TEXT NOT NULL,
  title TEXT,
  bio TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  credentials JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS expert_specialties (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  expert_id UUID NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
  specialty TEXT NOT NULL,
  tags JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS expert_availability (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  expert_id UUID NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
  weekday SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  starts_at TIME NOT NULL,
  ends_at TIME NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS expert_waitlist (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  preferred_focus JSONB NOT NULL DEFAULT '[]',
  note TEXT,
  status TEXT NOT NULL DEFAULT 'waiting',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS expert_match_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expert_id UUID REFERENCES experts(id) ON DELETE SET NULL,
  requested_focus JSONB NOT NULL DEFAULT '[]',
  status TEXT NOT NULL DEFAULT 'queued',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON chat_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id ON chat_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_emotion_analyses_user_id ON emotion_analyses(user_id);
CREATE INDEX IF NOT EXISTS idx_wellness_entries_user_id ON wellness_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_subscription_id ON subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscription_events_user_id ON subscription_events(user_id);
CREATE INDEX IF NOT EXISTS idx_experts_status ON experts(status);
CREATE INDEX IF NOT EXISTS idx_expert_specialties_expert_id ON expert_specialties(expert_id);
CREATE INDEX IF NOT EXISTS idx_expert_availability_expert_id ON expert_availability(expert_id);
CREATE INDEX IF NOT EXISTS idx_expert_waitlist_user_id ON expert_waitlist(user_id);
CREATE INDEX IF NOT EXISTS idx_expert_match_requests_user_id ON expert_match_requests(user_id);
