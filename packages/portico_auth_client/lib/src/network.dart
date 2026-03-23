import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exceptions.dart';

/// A network client specifically for interacting with the authentication server.
class AuthNetworkClient {
  final http.Client _client;
  final Uri loginUrl;
  final Uri registerUrl;
  final Uri refreshUrl;
  final Uri logoutUrl;
  final Uri updatePasswordUrl;
  final bool needsClosing;

  AuthNetworkClient(
    this._client, {
    required this.loginUrl,
    required this.registerUrl,
    required this.refreshUrl,
    required this.logoutUrl,
    required this.updatePasswordUrl,
    this.needsClosing = false,
  });

  void close() {
    if (needsClosing) _client.close();
  }

  /// Sends an update password request.
  Future<void> updatePassword(
    String oldPassword,
    String newPassword, {
    required Map<String, String> headers,
  }) async {
    await _post(updatePasswordUrl, {
      'old_password': oldPassword,
      'new_password': newPassword,
    }, headers: headers);
  }

  /// Sends a login request.
  Future<Map<String, dynamic>> login(String userId, String password) async {
    return _post(loginUrl, {'user_id': userId, 'password': password});
  }

  /// Sends a registration request.
  Future<void> register(String userId, String password) async {
    await _post(registerUrl, {'user_id': userId, 'password': password});
  }

  /// Sends a refresh token request.
  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    return _post(refreshUrl, {'refresh_token': refreshToken});
  }

  /// Invalidates the [refreshToken].
  Future<void> logout(String refreshToken) async {
    try {
      await _post(logoutUrl, {'refresh_token': refreshToken});
    } catch (_) {
      // Best effort invalidation
    }
  }

  Future<Map<String, dynamic>> _post(
    Uri url,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final response = await _client.post(
      url,
      headers: {...?headers, 'content-type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    _handleError(response);
  }

  Never _handleError(http.Response response) {
    final body = _tryDecode(response.body);
    final message = body?['error'] ?? body?['message'] ?? response.reasonPhrase;

    switch (response.statusCode) {
      case 401:
        throw const AuthInvalidCredentialsException();
      case 409:
        throw const AuthUserAlreadyExistsException();
      case 400:
        throw AuthServerException(message, statusCode: 400);
      default:
        throw AuthServerException(
          'Unexpected server error: $message',
          statusCode: response.statusCode,
        );
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
