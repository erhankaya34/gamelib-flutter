-- Migration: Fix games table trigger error
-- Date: 2025-11-29
-- Description: Remove the broken create_activity_and_game trigger that references non-existent games table
--              The existing create_activity_from_game_log trigger already handles activities correctly

-- ============================================
-- Drop the problematic trigger and function
-- ============================================

DROP TRIGGER IF EXISTS create_activity_on_game_log ON game_logs;
DROP FUNCTION IF EXISTS create_activity_and_game();

-- ============================================
-- Ensure the correct activity trigger is in place
-- ============================================

-- The create_activity_from_game_log function and trigger from 002_social_features.sql
-- already handles creating activities correctly without needing a separate games table

-- Verify the correct trigger exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE trigger_name = 'game_log_activity_trigger'
    AND event_object_table = 'game_logs'
  ) THEN
    RAISE EXCEPTION 'game_log_activity_trigger not found - please run 002_social_features.sql first';
  END IF;

  RAISE NOTICE 'Migration completed successfully! Removed broken games table trigger.';
END $$;
