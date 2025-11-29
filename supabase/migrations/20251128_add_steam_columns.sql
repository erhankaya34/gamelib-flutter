-- Migration: Add Steam integration columns to game_logs table
-- Date: 2025-11-28
-- Description: Adds columns needed for Steam library sync functionality

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

-- Create index for efficient Steam library queries
CREATE INDEX IF NOT EXISTS idx_game_logs_source ON game_logs(source);
CREATE INDEX IF NOT EXISTS idx_game_logs_steam_app_id ON game_logs(steam_app_id);
CREATE INDEX IF NOT EXISTS idx_game_logs_user_source ON game_logs(user_id, source);

-- Add comment for documentation
COMMENT ON COLUMN game_logs.source IS 'Source of the game entry: manual (user added) or steam (imported from Steam)';
COMMENT ON COLUMN game_logs.steam_app_id IS 'Steam App ID if the game was imported from Steam';
COMMENT ON COLUMN game_logs.playtime_minutes IS 'Total playtime in minutes (from Steam)';
COMMENT ON COLUMN game_logs.last_synced_at IS 'Last time the game data was synced from Steam';
