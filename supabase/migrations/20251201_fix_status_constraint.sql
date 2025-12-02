-- Fix game_logs status check constraint to include 'backlog'
-- This migration updates the constraint to allow backlog status

-- Drop existing constraint (try multiple possible names)
ALTER TABLE game_logs DROP CONSTRAINT IF EXISTS game_logs_status_check;
ALTER TABLE game_logs DROP CONSTRAINT IF EXISTS game_logs_status_check1;

-- Add updated constraint with all valid status values including 'backlog'
ALTER TABLE game_logs ADD CONSTRAINT game_logs_status_check
  CHECK (status IN ('wishlist', 'playing', 'completed', 'dropped', 'backlog'));
