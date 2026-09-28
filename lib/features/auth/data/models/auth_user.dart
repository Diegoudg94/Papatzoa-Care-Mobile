class AuthUser {
  const AuthUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.isTherapist,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as int,
    firstName: json['nombre'] as String,
    lastName: (json['apellido'] as String?) ?? '',
    email: json['correo'] as String,
    isTherapist: json['terapeuta'] as bool,
    role: json['role'] as String,
  );

  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final bool isTherapist;
}
