class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.username,
  });

  final String id;
  final String email;
  final String? username;

  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      id: data['id'] as String,
      email: data['email'] as String,
      username: data['username'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'username': username,
    };
  }
}
