-- ============================================
-- GameLib Flutter Database Schema
-- Purpose: Store user profiles, game collections, and stats
-- ============================================

-- Enable UUID extension for generating unique IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TABLE 1: profiles
-- Purpose: Store user profile information (extends Supabase auth.users)
-- ============================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  username TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TABLE 2: game_logs
-- Purpose: Store user's game collection and wishlist entries
-- ============================================
CREATE TABLE IF NOT EXISTS public.game_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  game_id INTEGER NOT NULL,                    -- IGDB game ID
  game_name TEXT NOT NULL,                     -- Game name for quick display
  game_cover_url TEXT,                         -- Cover image URL
  game_data JSONB,                             -- Full Game model stored as JSON
  status TEXT NOT NULL CHECK (status IN ('wishlist', 'playing', 'completed', 'dropped')),
  rating INTEGER CHECK (rating >= 1 AND rating <= 10),  -- Optional rating (1-10)
  notes TEXT,                                  -- User's notes about the game
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, game_id)                     -- Each user can have one entry per game
);

-- ============================================
-- TABLE 3: user_stats
-- Purpose: Store computed statistics (auto-updated via trigger)
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_stats (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  total_games INTEGER DEFAULT 0,
  completed_games INTEGER DEFAULT 0,
  wishlist_games INTEGER DEFAULT 0,
  playing_games INTEGER DEFAULT 0,
  dropped_games INTEGER DEFAULT 0,
  average_rating DECIMAL(3,1),                 -- Average of all ratings
  favorite_genre TEXT,                         -- Most played genre
  current_badge_tier INTEGER DEFAULT 0,        -- Current badge level (0-5)
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TABLE 4: badges
-- Purpose: Define badge tiers and requirements
-- ============================================
CREATE TABLE IF NOT EXISTS public.badges (
  tier INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  required_games INTEGER NOT NULL,
  icon_name TEXT NOT NULL
);

-- Insert badge definitions (6 tiers)
INSERT INTO public.badges (tier, name, description, required_games, icon_name) VALUES
(0, 'Yeni Oyuncu', 'Koleksiyona ilk adım', 0, 'gamepad'),
(1, 'Oyun Sever', '25 oyun tamamladı', 25, 'trophy'),
(2, 'Koleksiyoner', '50 oyun tamamladı', 50, 'star'),
(3, 'Uzman Oyuncu', '100 oyun tamamladı', 100, 'crown'),
(4, 'Efsane', '250 oyun tamamladı', 250, 'fire'),
(5, 'Ölümsüz', '500+ oyun tamamladı', 500, 'infinity')
ON CONFLICT (tier) DO NOTHING;

-- ============================================
-- INDEXES for Performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_game_logs_user_id ON public.game_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_game_logs_status ON public.game_logs(status);
CREATE INDEX IF NOT EXISTS idx_game_logs_user_status ON public.game_logs(user_id, status);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- Purpose: Ensure users can only access their own data
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_stats ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can view and update their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Game Logs: Users can fully manage their own game entries
CREATE POLICY "Users can view own game logs" ON public.game_logs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own game logs" ON public.game_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own game logs" ON public.game_logs
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own game logs" ON public.game_logs
  FOR DELETE USING (auth.uid() = user_id);

-- User Stats: Users can only view their own stats
CREATE POLICY "Users can view own stats" ON public.user_stats
  FOR SELECT USING (auth.uid() = user_id);

-- Badges: Everyone can view badges (read-only)
CREATE POLICY "Anyone can view badges" ON public.badges
  FOR SELECT USING (true);

-- ============================================
-- TRIGGER FUNCTION: Auto-update user stats
-- Purpose: Recompute stats whenever game_logs change
-- ============================================
CREATE OR REPLACE FUNCTION update_user_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Recompute stats for the affected user
  INSERT INTO public.user_stats (
    user_id,
    total_games,
    completed_games,
    wishlist_games,
    playing_games,
    dropped_games,
    average_rating,
    favorite_genre,
    current_badge_tier,
    updated_at
  )
  SELECT
    user_id,
    COUNT(*) as total_games,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_games,
    COUNT(*) FILTER (WHERE status = 'wishlist') as wishlist_games,
    COUNT(*) FILTER (WHERE status = 'playing') as playing_games,
    COUNT(*) FILTER (WHERE status = 'dropped') as dropped_games,
    AVG(rating) FILTER (WHERE rating IS NOT NULL) as average_rating,
    (
      -- Find most common genre from completed games
      SELECT genre
      FROM (
        SELECT jsonb_array_elements_text(game_data->'genres') as genre
        FROM public.game_logs
        WHERE user_id = COALESCE(NEW.user_id, OLD.user_id)
          AND status = 'completed'
      ) genres
      GROUP BY genre
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ) as favorite_genre,
    (
      -- Calculate current badge tier based on completed games
      SELECT MAX(tier)
      FROM public.badges
      WHERE required_games <= (
        SELECT COUNT(*)
        FROM public.game_logs
        WHERE user_id = COALESCE(NEW.user_id, OLD.user_id)
          AND status = 'completed'
      )
    ) as current_badge_tier,
    NOW() as updated_at
  FROM public.game_logs
  WHERE user_id = COALESCE(NEW.user_id, OLD.user_id)
  GROUP BY user_id
  ON CONFLICT (user_id)
  DO UPDATE SET
    total_games = EXCLUDED.total_games,
    completed_games = EXCLUDED.completed_games,
    wishlist_games = EXCLUDED.wishlist_games,
    playing_games = EXCLUDED.playing_games,
    dropped_games = EXCLUDED.dropped_games,
    average_rating = EXCLUDED.average_rating,
    favorite_genre = EXCLUDED.favorite_genre,
    current_badge_tier = EXCLUDED.current_badge_tier,
    updated_at = NOW();

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Run update_user_stats after any game_logs change
DROP TRIGGER IF EXISTS game_logs_stats_trigger ON public.game_logs;
CREATE TRIGGER game_logs_stats_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.game_logs
  FOR EACH ROW
  EXECUTE FUNCTION update_user_stats();

-- ============================================
-- TRIGGER FUNCTION: Auto-create profile on signup
-- Purpose: Create profile entry when user signs up
-- ============================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Create profile when auth.users gets new user
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
  RAISE NOTICE 'GameLib database schema created successfully! 🎮';
  RAISE NOTICE 'Tables created: profiles, game_logs, user_stats, badges';
  RAISE NOTICE 'RLS policies enabled for security';
  RAISE NOTICE 'Auto-stats trigger configured';
END $$;
