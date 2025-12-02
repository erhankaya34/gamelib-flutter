-- Add PlayStation fields to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS psn_id TEXT,
ADD COLUMN IF NOT EXISTS psn_account_id TEXT,
ADD COLUMN IF NOT EXISTS psn_avatar_url TEXT,
ADD COLUMN IF NOT EXISTS psn_access_token TEXT,
ADD COLUMN IF NOT EXISTS psn_refresh_token TEXT,
ADD COLUMN IF NOT EXISTS psn_linked_at TIMESTAMPTZ;

-- Add PlayStation title ID to game_logs table
ALTER TABLE game_logs
ADD COLUMN IF NOT EXISTS psn_title_id TEXT;

-- Update source check constraint to include 'playstation' and 'steam_wishlist'
-- First drop the existing constraint (it may have different names depending on how it was created)
DO $$
BEGIN
  -- Try to drop constraint by common names
  ALTER TABLE game_logs DROP CONSTRAINT IF EXISTS game_logs_source_check;
  ALTER TABLE game_logs DROP CONSTRAINT IF EXISTS game_logs_source_check1;

  -- Also drop any inline check constraints on the source column
  -- by recreating the column constraint
EXCEPTION
  WHEN undefined_object THEN
    NULL; -- Constraint doesn't exist, continue
END $$;

-- Add the updated constraint with all valid sources
ALTER TABLE game_logs DROP CONSTRAINT IF EXISTS game_logs_source_check;
ALTER TABLE game_logs ADD CONSTRAINT game_logs_source_check
  CHECK (source IN ('manual', 'steam', 'steam_wishlist', 'playstation'));

-- Create index for PSN title ID lookups
CREATE INDEX IF NOT EXISTS idx_game_logs_psn_title_id ON game_logs(psn_title_id) WHERE psn_title_id IS NOT NULL;

-- Create index for PSN ID lookups on profiles
CREATE INDEX IF NOT EXISTS idx_profiles_psn_id ON profiles(psn_id) WHERE psn_id IS NOT NULL;

-- Comment for documentation
COMMENT ON COLUMN profiles.psn_id IS 'PlayStation Network Online ID (username)';
COMMENT ON COLUMN profiles.psn_account_id IS 'PlayStation Network Account ID';
COMMENT ON COLUMN profiles.psn_access_token IS 'PSN API access token (encrypted at rest)';
COMMENT ON COLUMN profiles.psn_refresh_token IS 'PSN API refresh token (encrypted at rest)';
COMMENT ON COLUMN profiles.psn_linked_at IS 'Timestamp when PSN account was linked';
COMMENT ON COLUMN game_logs.psn_title_id IS 'PlayStation title ID (npCommunicationId) for PSN games';
