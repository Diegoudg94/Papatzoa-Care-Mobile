class AuthUser {
  const AuthUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.isTherapist,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as int,
    firstName: json['nombre'] as String,
    lastName: (json['apellido'] as String?) ?? '',
    email: json['correo'] as String,
    isTherapist: json['terapeuta'] as bool,
    role: json['role'] as String,
    avatarUrl: json['avatar_url'] is String
        ? json['avatar_url'] as String
        : null,
  );

  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final bool isTherapist;
  final String? avatarUrl;
}
