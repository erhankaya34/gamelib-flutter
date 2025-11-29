-- GameLib Database Reset Script
-- WARNING: This will delete ALL data permanently
-- Run in Supabase SQL Editor

-- Drop tables in reverse dependency order to avoid foreign key errors
DROP TABLE IF EXISTS public.activities CASCADE;
DROP TABLE IF EXISTS public.user_games CASCADE;
DROP TABLE IF EXISTS public.games CASCADE;
DROP TABLE IF EXISTS public.friendships CASCADE;
DROP TABLE IF EXISTS public.user_genres CASCADE;
DROP TABLE IF EXISTS public.user_stats CASCADE;
DROP TABLE IF EXISTS public.badges CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Drop functions and triggers
DROP FUNCTION IF EXISTS public.update_user_stats() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.create_activity_from_user_game() CASCADE;
DROP FUNCTION IF EXISTS public.update_steam_sync_timestamp() CASCADE;

-- Drop RLS policies are automatically removed with tables

-- Delete all auth users (this will cascade to profiles)
-- NOTE: This requires service_role key or admin privileges
DELETE FROM auth.users;

-- Verify clean state
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT LIKE 'pg_%'
  AND tablename NOT LIKE 'sql_%';

-- Expected result: Only system tables (if any)
