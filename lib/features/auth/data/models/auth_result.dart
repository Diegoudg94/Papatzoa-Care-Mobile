import 'auth_user.dart';

class AuthResult {
  const AuthResult({
    required this.user,
    required this.token,
    required this.message,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String;
    if (token.trim().isEmpty) throw const FormatException('Missing token');
    return AuthResult(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      token: token,
      message: json['message'] as String,
    );
  }

  final AuthUser user;
  final String token;
  final String message;
}
