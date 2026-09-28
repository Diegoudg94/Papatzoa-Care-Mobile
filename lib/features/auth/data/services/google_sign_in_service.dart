import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/network/api_exceptions.dart';

class GoogleSignInService {
  // Shared across service instances, including concurrent initialization calls.
  static Future<void>? _initialization;

  Future<String?> signIn() async {
    try {
      final signIn = GoogleSignIn.instance;
      await (_initialization ??= signIn.initialize());
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException('No pudimos validar tu cuenta de Google.');
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const ApiException(
        'No pudimos conectar con Papatzoa. Intenta nuevamente.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'No pudimos conectar con Papatzoa. Intenta nuevamente.',
      );
    }
  }
}
