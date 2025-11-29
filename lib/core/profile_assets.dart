/// Profile customization assets
/// Avatar and background image options

class ProfileAssets {
  // Avatar options - using placeholder images
  static const avatars = [
    'avatar_1',
    'avatar_2',
    'avatar_3',
    'avatar_4',
    'avatar_5',
    'avatar_6',
    'avatar_7',
    'avatar_8',
  ];

  // Background options
  static const backgrounds = [
    'bg_1',
    'bg_2',
    'bg_3',
    'bg_4',
    'bg_5',
    'bg_6',
    'bg_7',
    'bg_8',
  ];

  /// Get avatar URL from avatar ID
  static String getAvatarUrl(String avatarId) {
    // Using placeholder avatar service
    // Format: https://api.dicebear.com/7.x/avataaars/svg?seed={avatarId}
    return 'https://api.dicebear.com/7.x/avataaars/svg?seed=$avatarId';
  }

  /// Get background URL from background ID
  static String getBackgroundUrl(String backgroundId) {
    // Using placeholder gradient backgrounds
    // You can replace these with actual images later
    final gradients = {
      'bg_1': 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      'bg_2': 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
      'bg_3': 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)',
      'bg_4': 'linear-gradient(135deg, #43e97b 0%, #38f9d7 100%)',
      'bg_5': 'linear-gradient(135deg, #fa709a 0%, #fee140 100%)',
      'bg_6': 'linear-gradient(135deg, #30cfd0 0%, #330867 100%)',
      'bg_7': 'linear-gradient(135deg, #a8edea 0%, #fed6e3 100%)',
      'bg_8': 'linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%)',
    };

    return gradients[backgroundId] ?? gradients['bg_1']!;
  }

  /// Get background image URL (using placeholder images)
  static String getBackgroundImageUrl(String backgroundId) {
    // Using unsplash for gaming-themed backgrounds
    final images = {
      'bg_1': 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=1200&q=80', // Gaming setup
      'bg_2': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&q=80', // Gaming controller
      'bg_3': 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=1200&q=80', // Neon gaming
      'bg_4': 'https://images.unsplash.com/photo-1614294148960-9aa740632a87?w=1200&q=80', // Gaming room
      'bg_5': 'https://images.unsplash.com/photo-1592155931584-901ac15763e3?w=1200&q=80', // Gaming gear
      'bg_6': 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=1200&q=80', // Console gaming
      'bg_7': 'https://images.unsplash.com/photo-1612287230202-1ff1d85d1bdf?w=1200&q=80', // PC gaming
      'bg_8': 'https://images.unsplash.com/photo-1556438064-2d7646166914?w=1200&q=80', // Retro gaming
    };

    return images[backgroundId] ?? images['bg_1']!;
  }

  /// Get avatar display name
  static String getAvatarName(String avatarId) {
    final names = {
      'avatar_1': 'Gezgin',
      'avatar_2': 'Savaşçı',
      'avatar_3': 'Büyücü',
      'avatar_4': 'Ninja',
      'avatar_5': 'Şövalye',
      'avatar_6': 'Okçu',
      'avatar_7': 'Korsanlar',
      'avatar_8': 'Astronot',
    };

    return names[avatarId] ?? 'Avatar';
  }

  /// Get background display name
  static String getBackgroundName(String backgroundId) {
    final names = {
      'bg_1': 'Mor Degrade',
      'bg_2': 'Pembe Tutku',
      'bg_3': 'Mavi Okyanus',
      'bg_4': 'Yeşil Orman',
      'bg_5': 'Gün Batımı',
      'bg_6': 'Gece Gökyüzü',
      'bg_7': 'Pastel Rüya',
      'bg_8': 'Pembe Bulut',
    };

    return names[backgroundId] ?? 'Arkaplan';
  }
}
