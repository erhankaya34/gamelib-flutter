-- ============================================
-- Profile Customization Migration
-- ============================================
-- Adds profile customization fields and Steam integration

-- Add new columns to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS avatar TEXT DEFAULT 'avatar_1',
ADD COLUMN IF NOT EXISTS background_image TEXT DEFAULT 'bg_1',
ADD COLUMN IF NOT EXISTS steam_id TEXT,
ADD COLUMN IF NOT EXISTS steam_data JSONB;

-- Create index on steam_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_steam_id ON profiles(steam_id);

-- Add comment explaining steam_data structure
COMMENT ON COLUMN profiles.steam_data IS 'Cached Steam data: {profile_image_url, total_games, total_playtime_hours, total_achievements, last_synced}';

-- Create function to update steam_data timestamp
CREATE OR REPLACE FUNCTION update_steam_data_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.steam_data IS NOT NULL THEN
    NEW.steam_data = jsonb_set(
      COALESCE(NEW.steam_data, '{}'::jsonb),
      '{last_synced}',
      to_jsonb(NOW())
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update steam_data timestamp
DROP TRIGGER IF EXISTS trigger_update_steam_data_timestamp ON profiles;
CREATE TRIGGER trigger_update_steam_data_timestamp
  BEFORE UPDATE OF steam_data ON profiles
  FOR EACH ROW
  WHEN (NEW.steam_data IS DISTINCT FROM OLD.steam_data)
  EXECUTE FUNCTION update_steam_data_timestamp();

-- Update RLS policies to allow users to update their own profile customization
-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can update own profile customization" ON profiles;

-- Create the policy
CREATE POLICY "Users can update own profile customization"
ON profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);
