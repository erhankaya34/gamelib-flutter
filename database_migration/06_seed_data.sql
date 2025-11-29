-- ============================================
-- SEED DATA: Initial Static Content
-- ============================================

-- ============================================
-- BADGES: Achievement tier definitions
-- ============================================

INSERT INTO public.badges (tier, name, description, required_games, icon_name) VALUES
  (0, 'Yeni Oyuncu', 'Oyun koleksiyonuna hoş geldin!', 0, 'star'),
  (1, 'Oyun Sever', 'İlk 25 oyununu tamamladın', 25, 'trophy'),
  (2, 'Koleksiyoner', '50 oyun tamamlamak etkileyici!', 50, 'medal'),
  (3, 'Uzman Oyuncu', '100 oyun! Gerçek bir oyuncu oldun', 100, 'crown'),
  (4, 'Efsane', '250 oyun tamamlamak efsanevi bir başarı', 250, 'gem'),
  (5, 'Ölümsüz', '500+ oyun! Oyun tanrısısın!', 500, 'fire');

-- Verify seed data
SELECT * FROM public.badges ORDER BY tier;

-- Expected: 6 rows returned
