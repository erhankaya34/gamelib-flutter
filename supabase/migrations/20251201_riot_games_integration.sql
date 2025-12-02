-- Riot Games Integration Migration
-- Adds support for League of Legends, Valorant, and TFT

-- Add Riot Games fields to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS riot_puuid TEXT,
ADD COLUMN IF NOT EXISTS riot_game_name TEXT,
ADD COLUMN IF NOT EXISTS riot_tag_line TEXT,
ADD COLUMN IF NOT EXISTS riot_region TEXT,
ADD COLUMN IF NOT EXISTS riot_access_token TEXT,
ADD COLUMN IF NOT EXISTS riot_refresh_token TEXT,
ADD COLUMN IF NOT EXISTS riot_linked_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS riot_data JSONB;

-- Add Riot fields to game_logs table
ALTER TABLE game_logs
ADD COLUMN IF NOT EXISTS riot_game_id TEXT,
ADD COLUMN IF NOT EXISTS riot_ranked_data JSONB;

-- Update source check constraint to include 'riot', 'lol', 'valorant', 'tft'
DO $$
BEGIN
  ALTER TABLE game_logs DROP CONSTRAINT IF EXISTS game_logs_source_check;
  ALTER TABLE game_logs DROP CONSTRAINT IF EXISTS game_logs_source_check1;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

ALTER TABLE game_logs DROP CONSTRAINT IF EXISTS game_logs_source_check;
ALTER TABLE game_logs ADD CONSTRAINT game_logs_source_check
  CHECK (source IN ('manual', 'steam', 'steam_wishlist', 'playstation', 'riot', 'lol', 'valorant', 'tft'));

-- Create index for Riot PUUID lookups on profiles
CREATE INDEX IF NOT EXISTS idx_profiles_riot_puuid ON profiles(riot_puuid) WHERE riot_puuid IS NOT NULL;

-- Create index for Riot game ID lookups on game_logs
CREATE INDEX IF NOT EXISTS idx_game_logs_riot_game_id ON game_logs(riot_game_id) WHERE riot_game_id IS NOT NULL;

-- Comments for documentation
COMMENT ON COLUMN profiles.riot_puuid IS 'Riot Games Player Universally Unique ID';
COMMENT ON COLUMN profiles.riot_game_name IS 'Riot Games username (gameName)';
COMMENT ON COLUMN profiles.riot_tag_line IS 'Riot Games tag (e.g., #TR1)';
COMMENT ON COLUMN profiles.riot_region IS 'Riot Games region (tr, euw, na, kr, etc.)';
COMMENT ON COLUMN profiles.riot_access_token IS 'RSO OAuth access token';
COMMENT ON COLUMN profiles.riot_refresh_token IS 'RSO OAuth refresh token';
COMMENT ON COLUMN profiles.riot_linked_at IS 'Timestamp when Riot account was linked';
COMMENT ON COLUMN profiles.riot_data IS 'Additional Riot account data (JSON)';
COMMENT ON COLUMN game_logs.riot_game_id IS 'Riot game identifier (lol, valorant, tft)';
COMMENT ON COLUMN game_logs.riot_ranked_data IS 'Ranked stats (tier, rank, LP, wins, losses)';
