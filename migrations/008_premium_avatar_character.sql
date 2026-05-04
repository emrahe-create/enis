ALTER TABLE users
  ADD COLUMN IF NOT EXISTS avatar_character_id TEXT,
  ADD COLUMN IF NOT EXISTS avatar_character_name TEXT,
  ADD COLUMN IF NOT EXISTS avatar_voice_style TEXT,
  ADD COLUMN IF NOT EXISTS avatar_visual_style TEXT,
  ADD COLUMN IF NOT EXISTS avatar_personality_style TEXT;
