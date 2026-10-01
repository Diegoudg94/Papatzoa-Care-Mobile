import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import 'api_exceptions.dart';

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUri = Uri.parse(
        '${(baseUrl ?? AppConfig.apiBaseUrl).replaceFirst(RegExp(r"/+$"), "")}/',
      );

  final http.Client _client;
  final Uri baseUri;

  Uri url(String path) {
    if (path.startsWith('/') || Uri.parse(path).hasScheme) {
      throw ArgumentError.value(path, 'path', 'Use a relative API path.');
    }
    return baseUri.resolve(path);
  }

  Future<http.Response> get(String path, {String? token}) =>
      _send('GET', path, token: token);

  Future<http.Response> post(String path, {Object? body, String? token}) =>
      _send('POST', path, body: body, token: token);

  Future<http.Response> put(String path, {Object? body, String? token}) =>
      _send('PUT', path, body: body, token: token);

  Future<http.Response> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<http.Response> delete(String path, {String? token}) =>
      _send('DELETE', path, token: token);

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    final request = http.Request(method, url(path));
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    try {
      final response = await (() async {
        final streamedResponse = await _client.send(request);
        return http.Response.fromStream(streamedResponse);
      })().timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'No se pudo completar la solicitud. Inténtalo de nuevo.',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
      return response;
    } on SocketException catch (_) {
      throw const NetworkException();
    } on http.ClientException catch (_) {
      throw const NetworkException();
    } on TimeoutException catch (_) {
      throw const NetworkException();
    }
  }

  void close() => _client.close();
}
