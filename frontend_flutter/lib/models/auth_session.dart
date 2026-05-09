class AuthSession {
  const AuthSession({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt = '',
    this.lastLoginAt = '',
  });

  final String userId;
  final String name;
  final String email;
  final String role;
  final String createdAt;
  final String lastLoginAt;

  bool get isAdmin => role.toLowerCase() == 'admin';

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'role': role,
      'created_at': createdAt,
      'last_login_at': lastLoginAt,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: json['user_id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      email: json['email']?.toString().trim().toLowerCase() ?? '',
      role: json['role']?.toString().trim().toLowerCase() ?? 'usuario',
      createdAt: json['created_at']?.toString().trim() ?? '',
      lastLoginAt: json['last_login_at']?.toString().trim() ?? '',
    );
  }
}
