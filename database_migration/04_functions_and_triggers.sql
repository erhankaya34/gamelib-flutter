-- ============================================
-- TRIGGERS & FUNCTIONS: Auto-computation Logic
-- ============================================

-- ============================================
-- FUNCTION: Create user profile on signup
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Create profile entry
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email);

  -- Create initial stats entry
  INSERT INTO public.user_stats (user_id)
  VALUES (NEW.id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- FUNCTION: Update user stats on game changes
-- ============================================

CREATE OR REPLACE FUNCTION public.update_user_stats()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_total INTEGER;
  v_completed INTEGER;
  v_wishlist INTEGER;
  v_playing INTEGER;
  v_dropped INTEGER;
  v_avg_rating DECIMAL(3,1);
  v_total_ratings INTEGER;
  v_favorite_genre TEXT;
  v_badge_tier INTEGER;
BEGIN
  -- Get user_id from the affected row
  IF TG_OP = 'DELETE' THEN
    v_user_id := OLD.user_id;
  ELSE
    v_user_id := NEW.user_id;
  END IF;

  -- Count games by status
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'completed'),
    COUNT(*) FILTER (WHERE status = 'wishlist'),
    COUNT(*) FILTER (WHERE status = 'playing'),
    COUNT(*) FILTER (WHERE status = 'dropped')
  INTO v_total, v_completed, v_wishlist, v_playing, v_dropped
  FROM public.user_games
  WHERE user_id = v_user_id;

  -- Calculate average rating
  SELECT
    AVG(rating)::DECIMAL(3,1),
    COUNT(rating)
  INTO v_avg_rating, v_total_ratings
  FROM public.user_games
  WHERE user_id = v_user_id AND rating IS NOT NULL;

  -- Determine favorite genre (most common among completed games)
  SELECT genre
  INTO v_favorite_genre
  FROM (
    SELECT UNNEST(g.genres) AS genre
    FROM public.user_games ug
    JOIN public.games g ON g.id = ug.game_id
    WHERE ug.user_id = v_user_id AND ug.status = 'completed'
  ) genre_list
  GROUP BY genre
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  -- Calculate badge tier based on completed games
  SELECT COALESCE(MAX(tier), 0)
  INTO v_badge_tier
  FROM public.badges
  WHERE required_games <= v_completed;

  -- Update stats
  UPDATE public.user_stats
  SET
    total_games = v_total,
    completed_games = v_completed,
    wishlist_games = v_wishlist,
    playing_games = v_playing,
    dropped_games = v_dropped,
    average_rating = v_avg_rating,
    total_ratings = v_total_ratings,
    favorite_genre = v_favorite_genre,
    current_badge_tier = v_badge_tier,
    updated_at = NOW()
  WHERE user_id = v_user_id;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger on user_games
CREATE TRIGGER user_games_stats_update
  AFTER INSERT OR UPDATE OR DELETE ON public.user_games
  FOR EACH ROW EXECUTE FUNCTION public.update_user_stats();

-- ============================================
-- FUNCTION: Create activity on game changes
-- ============================================

CREATE OR REPLACE FUNCTION public.create_activity_from_user_game()
RETURNS TRIGGER AS $$
DECLARE
  v_activity_type TEXT;
  v_old_value TEXT;
  v_new_value TEXT;
  v_metadata JSONB;
  v_game_name TEXT;
  v_game_cover TEXT;
BEGIN
  -- Only create activities for certain operations
  IF TG_OP = 'DELETE' THEN
    RETURN NULL; -- Don't create activity on delete
  END IF;

  -- Get game details
  SELECT name, cover_url
  INTO v_game_name, v_game_cover
  FROM public.games
  WHERE id = NEW.game_id;

  -- Determine activity type
  IF TG_OP = 'INSERT' THEN
    v_activity_type := 'game_added';
    v_new_value := NEW.status;
    v_metadata := jsonb_build_object('source', NEW.source);

  ELSIF TG_OP = 'UPDATE' THEN
    -- Status changed
    IF OLD.status != NEW.status THEN
      IF NEW.status = 'completed' THEN
        v_activity_type := 'completed';
      ELSE
        v_activity_type := 'status_changed';
      END IF;
      v_old_value := OLD.status;
      v_new_value := NEW.status;
      v_metadata := jsonb_build_object('old_status', OLD.status, 'new_status', NEW.status);

    -- Rating added/changed
    ELSIF (OLD.rating IS NULL AND NEW.rating IS NOT NULL) OR
          (OLD.rating IS NOT NULL AND NEW.rating IS NOT NULL AND OLD.rating != NEW.rating) THEN
      v_activity_type := 'rating_added';
      v_old_value := OLD.rating::TEXT;
      v_new_value := NEW.rating::TEXT;
      v_metadata := jsonb_build_object('rating', NEW.rating);

    ELSE
      -- No significant change, don't create activity
      RETURN NULL;
    END IF;
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
    metadata
  ) VALUES (
    NEW.user_id,
    v_activity_type,
    NEW.game_id,
    v_game_name,
    v_game_cover,
    v_old_value,
    v_new_value,
    v_metadata
  );

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger on user_games
CREATE TRIGGER user_games_create_activity
  AFTER INSERT OR UPDATE ON public.user_games
  FOR EACH ROW EXECUTE FUNCTION public.create_activity_from_user_game();

-- ============================================
-- FUNCTION: Update Steam sync timestamp
-- ============================================

CREATE OR REPLACE FUNCTION public.update_steam_sync_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  -- Update profile's steam_synced_at when steam_data changes
  IF NEW.steam_data IS DISTINCT FROM OLD.steam_data THEN
    NEW.steam_synced_at := NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger on profiles
CREATE TRIGGER profiles_steam_sync_update
  BEFORE UPDATE OF steam_data ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_steam_sync_timestamp();
