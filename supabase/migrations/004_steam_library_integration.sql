-- ============================================
-- Steam Library Integration Migration
-- ============================================
-- Adds Steam library import capabilities to game_logs table

-- Add Steam-specific columns to game_logs table
ALTER TABLE public.game_logs
ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'manual'
  CHECK (source IN ('manual', 'steam')),
ADD COLUMN IF NOT EXISTS steam_app_id INTEGER,
ADD COLUMN IF NOT EXISTS playtime_minutes INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;

-- Create index for Steam game lookups
CREATE INDEX IF NOT EXISTS idx_game_logs_steam_app_id
  ON public.game_logs(steam_app_id)
  WHERE steam_app_id IS NOT NULL;

-- Create index for source filtering
CREATE INDEX IF NOT EXISTS idx_game_logs_source
  ON public.game_logs(user_id, source);

-- Create index for playtime sorting
CREATE INDEX IF NOT EXISTS idx_game_logs_playtime
  ON public.game_logs(user_id, playtime_minutes DESC);

-- Add comments explaining the schema
COMMENT ON COLUMN public.game_logs.source IS
  'Source of the game entry: manual (user-added) or steam (auto-imported)';
COMMENT ON COLUMN public.game_logs.steam_app_id IS
  'Steam App ID for games imported from Steam';
COMMENT ON COLUMN public.game_logs.playtime_minutes IS
  'Total playtime in minutes (from Steam or manual tracking)';
COMMENT ON COLUMN public.game_logs.last_synced_at IS
  'Last time this game was synced from Steam (NULL for manual games)';

-- Update existing game_logs to have 'manual' source
UPDATE public.game_logs
SET source = 'manual'
WHERE source IS NULL;
