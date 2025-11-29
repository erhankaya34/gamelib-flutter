-- ============================================
-- ROW LEVEL SECURITY (RLS): Data Isolation
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_genres ENABLE ROW LEVEL SECURITY;

-- ============================================
-- PROFILES: Users can only access own profile
-- ============================================

CREATE POLICY profiles_select ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- ============================================
-- GAMES: Everyone can read (public catalog)
-- Only system can insert/update (via service role)
-- ============================================

CREATE POLICY games_select ON public.games
  FOR SELECT USING (true); -- Public read

-- No INSERT/UPDATE policies for regular users (use service_role for imports)

-- ============================================
-- USER_GAMES: Users manage own collection
-- ============================================

CREATE POLICY user_games_select ON public.user_games
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_games_insert ON public.user_games
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_games_update ON public.user_games
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY user_games_delete ON public.user_games
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- USER_STATS: Read-only for users
-- Updated by triggers only
-- ============================================

CREATE POLICY user_stats_select ON public.user_stats
  FOR SELECT USING (auth.uid() = user_id);

-- ============================================
-- BADGES: Public read-only
-- ============================================

CREATE POLICY badges_select ON public.badges
  FOR SELECT USING (true);

-- ============================================
-- FRIENDSHIPS: Users see their relationships
-- ============================================

CREATE POLICY friendships_select ON public.friendships
  FOR SELECT USING (
    auth.uid() = user_id OR auth.uid() = friend_id
  );

CREATE POLICY friendships_insert ON public.friendships
  FOR INSERT WITH CHECK (
    auth.uid() = requested_by AND auth.uid() = user_id
  );

CREATE POLICY friendships_update ON public.friendships
  FOR UPDATE USING (
    auth.uid() = user_id OR auth.uid() = friend_id
  );

CREATE POLICY friendships_delete ON public.friendships
  FOR DELETE USING (
    auth.uid() = user_id OR auth.uid() = friend_id
  );

-- ============================================
-- ACTIVITIES: Users see own + friends' activities
-- ============================================

CREATE POLICY activities_select ON public.activities
  FOR SELECT USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.friendships
      WHERE status = 'accepted'
        AND ((user_id = auth.uid() AND friend_id = activities.user_id) OR
             (friend_id = auth.uid() AND user_id = activities.user_id))
    )
  );

-- Activities inserted by trigger only (no direct INSERT policy)

-- ============================================
-- USER_GENRES: Users manage own preferences
-- ============================================

CREATE POLICY user_genres_select ON public.user_genres
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_genres_insert ON public.user_genres
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_genres_delete ON public.user_genres
  FOR DELETE USING (auth.uid() = user_id);
