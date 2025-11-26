-- ================================================
-- GameLib Social Features Migration
-- ================================================
-- Creates tables for:
-- - friendships (friend system)
-- - user_genres (genre preferences from onboarding)
-- - activities (activity feed)
-- - Modifies profiles table for username uniqueness
-- ================================================

-- ================================================
-- TABLE 1: friendships
-- ================================================
-- Bi-directional friendship system with request/accept flow
-- Each accepted friendship creates TWO rows for efficient queries

CREATE TABLE IF NOT EXISTS public.friendships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected')),
  requested_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CONSTRAINT no_self_friendship CHECK (user_id != friend_id),
  CONSTRAINT unique_friendship UNIQUE(user_id, friend_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_friendships_user_id ON public.friendships(user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_friend_id ON public.friendships(friend_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON public.friendships(status);
CREATE INDEX IF NOT EXISTS idx_friendships_user_status ON public.friendships(user_id, status);

-- RLS Policies
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- Users can view friendships where they are involved
CREATE POLICY "Users can view own friendships"
  ON public.friendships
  FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- Users can create friend requests (only as the requester)
CREATE POLICY "Users can create friend requests"
  ON public.friendships
  FOR INSERT
  WITH CHECK (auth.uid() = requested_by AND auth.uid() = user_id);

-- Users can update friendships where they are involved
CREATE POLICY "Users can update friend requests"
  ON public.friendships
  FOR UPDATE
  USING (auth.uid() = friend_id OR auth.uid() = user_id);

-- Users can delete their own friendships
CREATE POLICY "Users can delete friendships"
  ON public.friendships
  FOR DELETE
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- ================================================
-- TABLE 2: user_genres
-- ================================================
-- Stores user's favorite game genres (from onboarding)
-- Used for personalized recommendations

CREATE TABLE IF NOT EXISTS public.user_genres (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  genre_name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Ensure unique genre per user
  CONSTRAINT unique_user_genre UNIQUE(user_id, genre_name)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_genres_user_id ON public.user_genres(user_id);
CREATE INDEX IF NOT EXISTS idx_user_genres_genre_name ON public.user_genres(genre_name);

-- RLS Policies
ALTER TABLE public.user_genres ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own genres"
  ON public.user_genres
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own genres"
  ON public.user_genres
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own genres"
  ON public.user_genres
  FOR DELETE
  USING (auth.uid() = user_id);

-- ================================================
-- TABLE 3: activities
-- ================================================
-- Stores user game activities for the activity feed
-- Automatically populated via trigger on game_logs table

CREATE TABLE IF NOT EXISTS public.activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL CHECK (activity_type IN ('game_added', 'status_changed', 'rating_added', 'completed')),
  game_id INTEGER NOT NULL,
  game_name TEXT NOT NULL,
  game_cover_url TEXT,
  old_value TEXT,
  new_value TEXT,
  metadata JSONB, -- Additional data (rating value, notes excerpt, etc.)
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance (feed queries are sorted by created_at DESC)
CREATE INDEX IF NOT EXISTS idx_activities_user_id ON public.activities(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_created_at ON public.activities(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activities_user_created ON public.activities(user_id, created_at DESC);

-- RLS Policies
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;

-- Users can view activities of their friends + their own
CREATE POLICY "Users can view friend activities"
  ON public.activities
  FOR SELECT
  USING (
    user_id = auth.uid() OR
    user_id IN (
      SELECT friend_id FROM public.friendships
      WHERE user_id = auth.uid() AND status = 'accepted'
    )
  );

-- System can insert activities (via trigger)
CREATE POLICY "System can insert activities"
  ON public.activities
  FOR INSERT
  WITH CHECK (true);

-- ================================================
-- TRIGGER: Auto-Create Activities from Game Logs
-- ================================================
-- Fires when game_logs table is INSERT/UPDATE
-- Creates activity entries for: game_added, completed, status_changed, rating_added

CREATE OR REPLACE FUNCTION create_activity_from_game_log()
RETURNS TRIGGER AS $$
DECLARE
  activity_type TEXT;
  old_val TEXT;
  new_val TEXT;
  meta JSONB;
BEGIN
  -- INSERT: New game added
  IF TG_OP = 'INSERT' THEN
    activity_type := 'game_added';
    new_val := NEW.status;
    meta := jsonb_build_object('initial_status', NEW.status);

  -- UPDATE: Status or rating changed
  ELSIF TG_OP = 'UPDATE' THEN
    -- Check if status changed
    IF OLD.status != NEW.status THEN
      -- Special case: completed status
      IF NEW.status = 'completed' THEN
        activity_type := 'completed';
      ELSE
        activity_type := 'status_changed';
      END IF;
      old_val := OLD.status;
      new_val := NEW.status;
      meta := jsonb_build_object('from_status', OLD.status, 'to_status', NEW.status);

    -- Check if rating added or changed
    ELSIF (OLD.rating IS NULL AND NEW.rating IS NOT NULL) OR (OLD.rating != NEW.rating) THEN
      activity_type := 'rating_added';
      old_val := COALESCE(OLD.rating::TEXT, 'none');
      new_val := NEW.rating::TEXT;
      meta := jsonb_build_object('rating', NEW.rating);

    ELSE
      -- No significant change, skip activity creation
      RETURN NEW;
    END IF;

  -- DELETE: Don't create activity
  ELSE
    RETURN OLD;
  END IF;

  -- Insert activity
  INSERT INTO public.activities (
    user_id,
    activity_type,
    game_id,
    game_name,
    game_cover_url,
    old_value,
    new_value,
    metadata,
    created_at
  ) VALUES (
    NEW.user_id,
    activity_type,
    NEW.game_id,
    NEW.game_name,
    NEW.game_cover_url,
    old_val,
    new_val,
    meta,
    NOW()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS game_log_activity_trigger ON public.game_logs;

-- Create trigger on game_logs table
CREATE TRIGGER game_log_activity_trigger
  AFTER INSERT OR UPDATE ON public.game_logs
  FOR EACH ROW
  EXECUTE FUNCTION create_activity_from_game_log();

-- ================================================
-- MODIFY: profiles table
-- ================================================
-- Add username unique constraint, format validation, onboarding flag

-- Add unique constraint to username (only when not null)
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username_unique
  ON public.profiles(username)
  WHERE username IS NOT NULL;

-- Enforce username format: 3-20 characters, alphanumeric + underscore
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS username_format;

ALTER TABLE public.profiles
  ADD CONSTRAINT username_format
  CHECK (username IS NULL OR (username ~ '^[a-zA-Z0-9_]{3,20}$'));

-- Add onboarding_completed flag
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;

-- ================================================
-- END OF MIGRATION
-- ================================================
