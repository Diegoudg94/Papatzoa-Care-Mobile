class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  const NetworkException([
    this.message =
        'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.',
  ]);

  final String message;

  @override
  String toString() => message;
}
