import 'package:flutter_test/flutter_test.dart';
import 'package:papatzoa_mobile/core/config/app_environment.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/network/api_exceptions.dart';

void main() {
  test('ApiClient uses AppConfig and keeps the API path', () {
    final client = ApiClient();
    addTearDown(client.close);

    expect(client.baseUri.toString(), '${AppConfig.apiBaseUrl}/');
    expect(client.url('example').toString(), '${AppConfig.apiBaseUrl}/example');
    expect(() => client.url('/example'), throwsArgumentError);
  });

  test('ApiClient accepts an injected base URL', () {
    final client = ApiClient(baseUrl: 'https://example.test/api/');
    addTearDown(client.close);

    expect(client.url('users').toString(), 'https://example.test/api/users');
  });

  test('Network and API errors have readable messages', () {
    expect(const NetworkException().message, contains('No se pudo conectar'));
    expect(
      const ApiException('Inténtalo de nuevo.', statusCode: 503).statusCode,
      503,
    );
  });
}
