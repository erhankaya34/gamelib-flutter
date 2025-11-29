-- ============================================
-- SOCIAL FEATURES: Friendships, Activities, Genres
-- ============================================

-- ============================================
-- TABLE: friendships
-- Purpose: Bidirectional friend relationships
-- ============================================

CREATE TABLE public.friendships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected')),
  requested_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  UNIQUE(user_id, friend_id), -- No duplicate relationships
  CHECK (user_id != friend_id) -- No self-friendships
);

-- Optimized Indexes (avoid N+1 patterns)
CREATE INDEX idx_friendships_user_id ON public.friendships(user_id);
CREATE INDEX idx_friendships_friend_id ON public.friendships(friend_id);
CREATE INDEX idx_friendships_status ON public.friendships(status);
CREATE INDEX idx_friendships_user_status ON public.friendships(user_id, status); -- Get user's friends by status
CREATE INDEX idx_friendships_friend_status ON public.friendships(friend_id, status); -- Get pending requests

-- Comments
COMMENT ON TABLE public.friendships IS 'Bidirectional friendship system with request/accept/reject flow';
COMMENT ON COLUMN public.friendships.requested_by IS 'Who initiated the friend request (for accept/reject logic)';

-- ============================================
-- TABLE: activities
-- Purpose: User activity feed (auto-populated by trigger)
-- ============================================

CREATE TABLE public.activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL CHECK (activity_type IN ('game_added', 'status_changed', 'rating_added', 'completed')),

  -- Game Reference (denormalized for performance)
  game_id BIGINT NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,
  game_name TEXT NOT NULL,
  game_cover_url TEXT,

  -- Change Tracking
  old_value TEXT,
  new_value TEXT,
  metadata JSONB, -- Flexible: {rating: 8, old_status: 'playing', new_status: 'completed'}

  -- Timestamp
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Performance Indexes for feed queries
CREATE INDEX idx_activities_user_id ON public.activities(user_id);
CREATE INDEX idx_activities_created_at ON public.activities(created_at DESC);
CREATE INDEX idx_activities_user_created ON public.activities(user_id, created_at DESC);
CREATE INDEX idx_activities_type ON public.activities(activity_type);

-- Comments
COMMENT ON TABLE public.activities IS 'Activity feed. Auto-populated when user_games change. Denormalized for feed performance.';
COMMENT ON COLUMN public.activities.game_name IS 'Denormalized from games table to avoid JOIN on every feed load';

-- ============================================
-- TABLE: user_genres
-- Purpose: User's favorite game genres (from onboarding)
-- ============================================

CREATE TABLE public.user_genres (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  genre_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  UNIQUE(user_id, genre_name) -- One entry per genre per user
);

-- Indexes
CREATE INDEX idx_user_genres_user_id ON public.user_genres(user_id);
CREATE INDEX idx_user_genres_genre_name ON public.user_genres(genre_name);

-- Comments
COMMENT ON TABLE public.user_genres IS 'User preferences from onboarding. Used for personalized recommendations.';
