-- Migration: Fix game_logs schema and activities trigger
-- Date: 2025-11-28
-- Description:
--   1. Add Steam integration columns to game_logs
--   2. Fix activities trigger to handle games table foreign key

-- ============================================
-- PART 1: Add Steam columns to game_logs
-- ============================================

-- Add source column to distinguish between manual and Steam-imported games
ALTER TABLE game_logs
ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'manual' CHECK (source IN ('manual', 'steam'));

-- Add Steam-specific columns
ALTER TABLE game_logs
ADD COLUMN IF NOT EXISTS steam_app_id INTEGER;

ALTER TABLE game_logs
ADD COLUMN IF NOT EXISTS playtime_minutes INTEGER DEFAULT 0;

ALTER TABLE game_logs
ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_game_logs_source ON game_logs(source);
CREATE INDEX IF NOT EXISTS idx_game_logs_steam_app_id ON game_logs(steam_app_id);
CREATE INDEX IF NOT EXISTS idx_game_logs_user_source ON game_logs(user_id, source);

-- Add comments for documentation
COMMENT ON COLUMN game_logs.source IS 'Source of the game entry: manual (user added) or steam (imported from Steam)';
COMMENT ON COLUMN game_logs.steam_app_id IS 'Steam App ID if the game was imported from Steam';
COMMENT ON COLUMN game_logs.playtime_minutes IS 'Total playtime in minutes (from Steam)';
COMMENT ON COLUMN game_logs.last_synced_at IS 'Last time the game data was synced from Steam';

-- ============================================
-- PART 2: Fix activities trigger
-- ============================================

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS create_activity_on_game_log ON game_logs;
DROP FUNCTION IF EXISTS create_activity_and_game();

-- Create new function that handles both games and activities tables
CREATE OR REPLACE FUNCTION create_activity_and_game()
RETURNS TRIGGER AS $$
BEGIN
  -- First, upsert to games table (if it doesn't exist)
  -- This ensures the foreign key constraint in activities will be satisfied
  INSERT INTO games (id, name, cover_url, data, created_at, updated_at)
  VALUES (
    NEW.game_id,
    NEW.game_name,
    NEW.game_cover_url,
    NEW.game_data,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    name = EXCLUDED.name,
    cover_url = EXCLUDED.cover_url,
    data = EXCLUDED.data,
    updated_at = NOW();

  -- Then create activity (only on INSERT, not UPDATE)
  IF (TG_OP = 'INSERT') THEN
    INSERT INTO activities (user_id, game_id, activity_type, created_at)
    VALUES (NEW.user_id, NEW.game_id, 'added_to_library', NOW());
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger that runs BEFORE insert/update
-- We use BEFORE so the games table is populated before the foreign key check
CREATE TRIGGER create_activity_on_game_log
  BEFORE INSERT OR UPDATE ON game_logs
  FOR EACH ROW
  EXECUTE FUNCTION create_activity_and_game();

-- ============================================
-- VERIFICATION
-- ============================================

-- Verify columns were added
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'game_logs' AND column_name = 'source'
  ) THEN
    RAISE EXCEPTION 'Migration failed: source column not added';
  END IF;

  RAISE NOTICE 'Migration completed successfully!';
END $$;
