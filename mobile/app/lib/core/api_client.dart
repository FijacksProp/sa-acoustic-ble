import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'error_messages.dart';
import 'session_store.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${ApiConfig.currentBaseUrl}$path');

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(
      _client.post(
        _uri(path),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
    return _decodeResponse(response);
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await _send(_client.get(_uri(path), headers: _headers()));
    final decoded = _decodeResponse(response);
    if (decoded['results'] is List<dynamic>) {
      return decoded['results'] as List<dynamic>;
    }
    throw ApiException('Unexpected list response format');
  }

  Future<Map<String, dynamic>> getMap(String path) async {
    final response = await _send(_client.get(_uri(path), headers: _headers()));
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _send(_client.delete(_uri(path), headers: _headers()));
    return _decodeResponse(response);
  }

  Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = SessionStore.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(const Duration(seconds: 20));
    } on TimeoutException catch (error) {
      throw ApiException(friendlyErrorMessage(error));
    } on SocketException catch (error) {
      throw ApiException(friendlyErrorMessage(error));
    } on http.ClientException catch (error) {
      throw ApiException(friendlyErrorMessage(error));
    } on FormatException catch (error) {
      throw ApiException(friendlyErrorMessage(error));
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } on FormatException {
      if (body.trimLeft().startsWith('<')) {
        throw ApiException(
          'The backend returned an unexpected page. Restart the backend and try again.',
          statusCode: response.statusCode,
        );
      }
      throw ApiException(
        'The backend returned a response the app could not read.',
        statusCode: response.statusCode,
      );
    }

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
      _friendlyServerError(response.statusCode, decoded),
      statusCode: response.statusCode,
    );
  }

  String _friendlyServerError(int statusCode, dynamic decoded) {
    final serverMessage = _extractServerMessage(decoded);
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }

    return switch (statusCode) {
      400 => 'Please check the form and try again.',
      401 => 'Your session has expired. Please log in again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'The requested record could not be found.',
      >= 500 => 'The backend had an internal error. Please restart it and try again.',
      _ => 'Request failed. Please try again.',
    };
  }

  String? _extractServerMessage(dynamic decoded) {
    if (decoded is String) {
      return decoded;
    }
    if (decoded is List && decoded.isNotEmpty) {
      return _extractServerMessage(decoded.first);
    }
    if (decoded is Map) {
      for (final key in ['detail', 'non_field_errors', 'error', 'message']) {
        if (decoded.containsKey(key)) {
          final message = _extractServerMessage(decoded[key]);
          if (message != null && message.isNotEmpty) {
            return message;
          }
        }
      }
      for (final entry in decoded.entries) {
        final message = _extractServerMessage(entry.value);
        if (message != null && message.isNotEmpty) {
          final field = _humanFieldName(entry.key.toString());
          return '$field: $message';
        }
      }
    }
    return null;
  }

  String _humanFieldName(String field) {
    return field
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
