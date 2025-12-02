-- Fix game_logs source check constraint to include 'playstation' and 'steam_wishlist'
-- This migration updates the constraint to allow PlayStation games to be saved

-- Drop existing constraint (try multiple possible names)
ALTER TABLE game_logs DROP CONSTRAINT IF EXISTS game_logs_source_check;
ALTER TABLE game_logs DROP CONSTRAINT IF EXISTS game_logs_source_check1;

-- Add updated constraint with all valid source values
ALTER TABLE game_logs ADD CONSTRAINT game_logs_source_check
  CHECK (source IN ('manual', 'steam', 'steam_wishlist', 'playstation'));
