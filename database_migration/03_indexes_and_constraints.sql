-- ============================================
-- PERFORMANCE OPTIMIZATION: Additional Indexes & Constraints
-- ============================================

-- ============================================
-- Composite Indexes for Common Query Patterns
-- ============================================

-- Pattern: Get user's Steam library sorted by playtime
CREATE INDEX idx_user_games_steam_playtime
ON public.user_games(user_id, playtime_minutes DESC)
WHERE source = 'steam';

-- Pattern: Get user's manual collection sorted by date
CREATE INDEX idx_user_games_manual_recent
ON public.user_games(user_id, added_at DESC)
WHERE source = 'manual';

-- Pattern: Get wishlist games
CREATE INDEX idx_user_games_wishlist
ON public.user_games(user_id, added_at DESC)
WHERE status = 'wishlist';

-- Pattern: Get completed games for stats calculation
CREATE INDEX idx_user_games_completed
ON public.user_games(user_id, game_id)
WHERE status = 'completed';

-- Pattern: Friend activity feed (most common query)
CREATE INDEX idx_activities_friends_feed
ON public.activities(user_id, created_at DESC)
WHERE activity_type IN ('completed', 'rating_added');

-- ============================================
-- Pagination Support Indexes
-- ============================================

-- For offset-based pagination on large collections
CREATE INDEX idx_user_games_pagination
ON public.user_games(user_id, added_at DESC, id); -- Include ID for tie-breaking

-- For cursor-based pagination (more efficient)
CREATE INDEX idx_activities_cursor
ON public.activities(created_at DESC, id); -- Created + ID for stable cursor

-- ============================================
-- Additional Constraints
-- ============================================

-- Ensure email is lowercase (normalization)
ALTER TABLE public.profiles
ADD CONSTRAINT email_lowercase CHECK (email = LOWER(email));

-- Ensure playtime is non-negative
ALTER TABLE public.user_games
ADD CONSTRAINT playtime_non_negative CHECK (playtime_minutes >= 0);

-- Ensure rating count makes sense
ALTER TABLE public.user_stats
ADD CONSTRAINT ratings_consistency CHECK (
  (average_rating IS NULL AND total_ratings = 0) OR
  (average_rating IS NOT NULL AND total_ratings > 0)
);

-- ============================================
-- Updated Timestamp Triggers
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.user_games
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.user_stats
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- Analyze Tables for Query Planner
-- ============================================

ANALYZE public.profiles;
ANALYZE public.games;
ANALYZE public.user_games;
ANALYZE public.friendships;
ANALYZE public.activities;
ANALYZE public.user_genres;
ANALYZE public.user_stats;
ANALYZE public.badges;
