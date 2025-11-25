/// Badge (Rozet) Model
///
/// Her rozet bir seviyeyi temsil eder.
/// Kullanıcı tamamladığı oyun sayısına göre rozet kazanır.
///
/// Örnek: 25 oyun tamamlayan kullanıcı "Oyun Sever" rozetini kazanır.
class Badge {
  const Badge({
    required this.tier,
    required this.name,
    required this.description,
    required this.requiredGames,
    required this.iconName,
  });

  /// Rozet seviyesi (0-5)
  /// 0 = Yeni Oyuncu, 5 = Ölümsüz
  final int tier;

  /// Rozet adı (örn: "Oyun Sever")
  final String name;

  /// Rozet açıklaması (örn: "25 oyun tamamladı")
  final String description;

  /// Bu rozeti kazanmak için gereken tamamlanmış oyun sayısı
  final int requiredGames;

  /// İkon adı (FontAwesome icon için - örn: "trophy")
  final String iconName;

  /// Supabase'den gelen JSON'u Badge nesnesine çevir
  factory Badge.fromMap(Map<String, dynamic> json) {
    return Badge(
      tier: json['tier'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      requiredGames: json['required_games'] as int,
      iconName: json['icon_name'] as String,
    );
  }

  /// Badge nesnesini JSON'a çevir (Supabase'e gönderirken)
  Map<String, dynamic> toMap() {
    return {
      'tier': tier,
      'name': name,
      'description': description,
      'required_games': requiredGames,
      'icon_name': iconName,
    };
  }

  @override
  String toString() => 'Badge(tier: $tier, name: $name, requiredGames: $requiredGames)';
}
