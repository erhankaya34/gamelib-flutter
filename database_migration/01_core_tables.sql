-- ============================================
-- CORE TABLES: Profiles, Games, User Collections
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- For fuzzy text search

-- ============================================
-- TABLE: profiles
-- Purpose: User profile information and preferences
-- Extends Supabase auth.users with app-specific data
-- ============================================

CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  username TEXT UNIQUE,
  bio TEXT,
  avatar TEXT NOT NULL DEFAULT 'avatar_1',
  background_image TEXT NOT NULL DEFAULT 'bg_1',

  -- Steam Integration
  steam_id TEXT UNIQUE,
  steam_data JSONB, -- Flexible: {profile_image_url, persona_name, level}
  steam_synced_at TIMESTAMPTZ,

  -- Onboarding
  onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Constraints
ALTER TABLE public.profiles
  ADD CONSTRAINT username_length CHECK (username IS NULL OR char_length(username) BETWEEN 3 AND 20),
  ADD CONSTRAINT username_format CHECK (username IS NULL OR username ~ '^[a-zA-Z0-9_]+$');

-- Indexes
CREATE INDEX idx_profiles_username ON public.profiles(username) WHERE username IS NOT NULL;
CREATE INDEX idx_profiles_steam_id ON public.profiles(steam_id) WHERE steam_id IS NOT NULL;

-- Comments
COMMENT ON TABLE public.profiles IS 'User profiles with Steam integration and customization';
COMMENT ON COLUMN public.profiles.steam_data IS 'Flexible JSON storage for Steam API response data that may evolve';
COMMENT ON COLUMN public.profiles.steam_synced_at IS 'Last successful Steam profile sync timestamp';

-- ============================================
-- TABLE: games
-- Purpose: Master catalog of all games (IGDB + Steam)
-- Normalized: One entry per unique game across all users
-- ============================================

CREATE TABLE public.games (
  id BIGINT PRIMARY KEY, -- IGDB game ID
  name TEXT NOT NULL,
  slug TEXT,

  -- Media
  cover_url TEXT,
  screenshot_urls TEXT[], -- Array of screenshot URLs

  -- Metadata
  summary TEXT,
  platforms TEXT[], -- Array of platform names
  genres TEXT[], -- Array of genre names

  -- Ratings
  aggregated_rating DECIMAL(5,2), -- IGDB rating (0-100)
  user_rating DECIMAL(5,2), -- IGDB user rating (0-100)
  rating_count INTEGER,
  metacritic_score INTEGER,

  -- Release
  release_date DATE,

  -- Steam Mapping (if available)
  steam_app_id INTEGER UNIQUE, -- Steam App ID for cross-reference

  -- Cache Management
  first_added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for search and lookup
CREATE INDEX idx_games_name_trgm ON public.games USING gin(name gin_trgm_ops); -- Full-text search
CREATE INDEX idx_games_steam_app_id ON public.games(steam_app_id) WHERE steam_app_id IS NOT NULL;
CREATE INDEX idx_games_platforms ON public.games USING gin(platforms); -- Array search
CREATE INDEX idx_games_genres ON public.games USING gin(genres); -- Array search
CREATE INDEX idx_games_release_date ON public.games(release_date DESC) WHERE release_date IS NOT NULL;

-- Comments
COMMENT ON TABLE public.games IS 'Master game catalog. One entry per unique game, shared across all users.';
COMMENT ON COLUMN public.games.id IS 'IGDB game ID (primary identifier)';
COMMENT ON COLUMN public.games.steam_app_id IS 'Steam App ID for cross-reference (nullable, not all games on Steam)';
COMMENT ON COLUMN public.games.last_updated_at IS 'Cache invalidation: when game metadata was last refreshed from IGDB';

-- ============================================
-- TABLE: user_games
-- Purpose: User's personal game collection with status and tracking
-- Replaces old game_logs with normalized design
-- ============================================

CREATE TABLE public.user_games (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  game_id BIGINT NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,

  -- User Tracking
  status TEXT NOT NULL CHECK (status IN ('wishlist', 'playing', 'completed', 'dropped')),
  rating INTEGER CHECK (rating BETWEEN 1 AND 10),
  notes TEXT,

  -- Source Tracking
  source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'steam', 'epic', 'gog')),

  -- Steam Integration
  steam_app_id INTEGER, -- Redundant but useful for quick Steam-specific queries
  playtime_minutes INTEGER NOT NULL DEFAULT 0,
  steam_synced_at TIMESTAMPTZ,

  -- Timestamps
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  UNIQUE(user_id, game_id) -- One entry per game per user
);

-- Performance Indexes
CREATE INDEX idx_user_games_user_id ON public.user_games(user_id);
CREATE INDEX idx_user_games_game_id ON public.user_games(game_id);
CREATE INDEX idx_user_games_user_status ON public.user_games(user_id, status); -- Filter by status
CREATE INDEX idx_user_games_user_source ON public.user_games(user_id, source); -- Separate manual vs Steam
CREATE INDEX idx_user_games_playtime ON public.user_games(user_id, playtime_minutes DESC); -- Sort by playtime
CREATE INDEX idx_user_games_steam_app ON public.user_games(steam_app_id) WHERE steam_app_id IS NOT NULL;
CREATE INDEX idx_user_games_added_at ON public.user_games(user_id, added_at DESC); -- Recent additions

-- Comments
COMMENT ON TABLE public.user_games IS 'User game collection. References games master table instead of duplicating data.';
COMMENT ON COLUMN public.user_games.source IS 'Where game came from: manual (user added), steam (auto-imported), etc. Extensible for future platforms.';
COMMENT ON COLUMN public.user_games.steam_app_id IS 'Denormalized from games table for performance on Steam-specific queries';

-- ============================================
-- TABLE: user_stats
-- Purpose: Computed user statistics (auto-updated by trigger)
-- ============================================

CREATE TABLE public.user_stats (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- Game Counts
  total_games INTEGER NOT NULL DEFAULT 0,
  completed_games INTEGER NOT NULL DEFAULT 0,
  wishlist_games INTEGER NOT NULL DEFAULT 0,
  playing_games INTEGER NOT NULL DEFAULT 0,
  dropped_games INTEGER NOT NULL DEFAULT 0,

  -- Ratings
  average_rating DECIMAL(3,1),
  total_ratings INTEGER NOT NULL DEFAULT 0,

  -- Preferences
  favorite_genre TEXT,

  -- Achievements
  current_badge_tier INTEGER NOT NULL DEFAULT 0,

  -- Timestamps
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for badge tier sorting/filtering
CREATE INDEX idx_user_stats_badge_tier ON public.user_stats(current_badge_tier DESC);

-- Comments
COMMENT ON TABLE public.user_stats IS 'Denormalized statistics computed from user_games. Updated automatically by trigger.';
COMMENT ON COLUMN public.user_stats.favorite_genre IS 'Most common genre among completed games';

-- ============================================
-- TABLE: badges
-- Purpose: Static achievement tier definitions
-- ============================================

CREATE TABLE public.badges (
  tier INTEGER PRIMARY KEY CHECK (tier BETWEEN 0 AND 5),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  required_games INTEGER NOT NULL,
  icon_name TEXT NOT NULL
);

-- Comments
COMMENT ON TABLE public.badges IS 'Static badge definitions. 6 tiers from beginner to master.';
