import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await _client.get(_uri(path));
    final decoded = _decodeResponse(response);
    if (decoded['results'] is List<dynamic>) {
      return decoded['results'] as List<dynamic>;
    }
    throw ApiException('Unexpected list response format');
  }

  Future<Map<String, dynamic>> getMap(String path) async {
    final response = await _client.get(_uri(path));
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is List<dynamic>) {
        return {'results': decoded};
      }
      return {};
    }

    throw ApiException(
      'Request failed (${response.statusCode}): $decoded',
      statusCode: response.statusCode,
    );
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
