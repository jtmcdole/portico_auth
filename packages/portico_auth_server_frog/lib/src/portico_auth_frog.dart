import 'dart:io';

import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';

import 'models/user.dart';
import 'models/user_role.dart';

/// {@template portico_auth_frog}
/// A set of dart-frog handlers for Portico Authentication.
/// {@endtemplate}
class AuthFrog {
  /// {@macro portico_auth_frog}
  AuthFrog({
    required AuthTokensManager tokens,
    required AuthCredentialsManager credentials,
    required AuthRoleManager roles,
    int maxAuthContentLength = 10240,
  }) : _maxAuthContentLength = maxAuthContentLength,
       _tokens = tokens,
       _credentials = credentials,
       _roles = roles;

  final AuthTokensManager _tokens;
  final AuthCredentialsManager _credentials;
  final AuthRoleManager _roles;

  /// The maximum content-length for any auth body.
  final int _maxAuthContentLength;

  final _logger = Logger('AuthFrog');

  /// Authenticates a request using a bearer [token].
  ///
  /// Returns a [User] if the token is valid, otherwise `null`.
  Future<User?> authenticator(RequestContext context, String token) async {
    try {
      final payload = await _tokens.getPayload(token);
      final content = payload.jsonContent;

      final id = content['sub'] as String;
      // TODO(codefu): check for revocation - do not look up in database.
      // final serial = content['serial'] as String?;

      final roles = <UserRole>[];
      if (content['roles'] case List rolesRaw) {
        for (final item in rolesRaw) {
          if (item is Map<String, Object?>) {
            roles.add(UserRole.fromJson(item));
          }
        }
      }

      final metadata = <String, dynamic>{
        'iat': content['iat'],
        'exp': content['exp'],
        'serial': content['serial'],
      };

      return User(id: id, roles: roles, metadata: metadata);
    } on AccessTokenInvalid catch (e) {
      _logger.warning('Invalid access token', e);
      return null;
    } catch (e, s) {
      _logger.severe('Authentication failed', e, s);
      return null;
    }
  }

  /// Handles user login.
  ///
  /// Expects a JSON body with `user_id` and `password`.
  Future<Response> login(RequestContext context) async {
    try {
      final contentLength = int.tryParse(
        context.request.headers['content-length'] ?? '',
      );
      if (contentLength == null || contentLength > _maxAuthContentLength) {
        _logger.info('Login failed: bad payload size ($contentLength)');
        return Response(statusCode: HttpStatus.badRequest);
      }

      final body = await context.request.json() as Map<String, dynamic>;
      final userId = body['user_id'] as String?;
      final password = body['password'] as String?;

      if (userId == null || password == null) {
        _logger.info('Login failed: Missing user_id or password');
        return Response(statusCode: HttpStatus.badRequest);
      }

      await _credentials.verifyCredentials(userId, password);

      final roles = await _getUserRoles(userId);

      final tokens = await _tokens.mintTokens(
        userId,
        extraClaims: {'roles': roles},
      );

      return Response.json(body: tokens);
    } on FormatException catch (e) {
      _logger.info('Login failed: Invalid JSON format', e);
      return Response(statusCode: HttpStatus.badRequest);
    } on InvalidCredentialsException catch (e) {
      _logger.info('Login failed: Invalid credentials', e);
      return Response(statusCode: HttpStatus.unauthorized);
    } catch (e, s) {
      _logger.severe('Login failed: Internal error', e, s);
      return Response(statusCode: HttpStatus.internalServerError);
    }
  }

  Future<List<Map<String, dynamic>>> _getUserRoles(
    String userId, {
    bool includeInactive = false,
  }) async {
    final assignments = await _roles.getUserAssignments(userId);
    final roles = {
      for (final r in await _roles.listRoles(includeInactive: includeInactive))
        r.name,
    };
    return [
      for (final a in assignments)
        if (roles.contains(a.roleName)) {'role': a.roleName, 'scope': a.scope},
    ];
  }

  /// Handles user registration.
  ///
  /// Expects a JSON body with `user_id` and `password`.
  Future<Response> register(RequestContext context) async {
    try {
      final contentLength = int.tryParse(
        context.request.headers['content-length'] ?? '',
      );
      if (contentLength == null || contentLength > _maxAuthContentLength) {
        _logger.info('Registration failed: bad payload size ($contentLength)');
        return Response(statusCode: HttpStatus.badRequest);
      }

      final body = await context.request.json() as Map<String, dynamic>;
      final userId = body['user_id'] as String?;
      final password = body['password'] as String?;

      if (userId == null || password == null) {
        _logger.info('Registration failed: Missing user_id or password');
        return Response(statusCode: HttpStatus.badRequest);
      }

      await _credentials.registerUser(userId, password);

      // We return the user view, similar to what the authenticator returns but without roles for now
      // as a newly registered user usually has no roles unless default roles are assigned.
      // However, we should still query to be consistent.
      final rolesRaw = await _getUserRoles(userId);
      final roles = <UserRole>[];
      for (final item in rolesRaw) {
        roles.add(UserRole.fromJson(item));
      }

      final user = User(id: userId, roles: roles, metadata: {});
      return Response.json(body: user);
    } on FormatException catch (e) {
      _logger.info('Registration failed: Invalid JSON format', e);
      return Response(statusCode: HttpStatus.badRequest);
    } on UserAlreadyExistsException catch (e) {
      _logger.info('Registration failed: User already exists', e);
      return Response(statusCode: HttpStatus.conflict);
    } on InvalidCredentialsException catch (e) {
      _logger.info('Registration failed: Weak password', e);
      return Response(statusCode: HttpStatus.badRequest);
    } catch (e, s) {
      _logger.severe('Registration failed: Internal error', e, s);
      return Response(statusCode: HttpStatus.internalServerError);
    }
  }

  /// Generates a temporary token that can be used to authenticate requests.
  Future<Response> generateTempToken(RequestContext context) async {
    try {
      // The user object might not contain the raw access token needed for generation.
      // However, AuthTokensManager.generateTempToken takes an accessToken.
      // AuthFrog.authenticator validates the token but doesn't pass it through in the User object.
      // We need to extract the token from the context/request again or store it in User metadata.

      // Let's check how we can get the token.
      final authHeader = context.request.headers['authorization'];
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        final token = authHeader.substring(7).trim();
        final jwt = await _tokens.generateTempToken(token);
        return Response(
          body: jwt,
          headers: {'Content-Type': 'application/jwt'},
        );
      }
      return Response(statusCode: HttpStatus.badRequest);
    } catch (e, s) {
      _logger.warning('Failed to generate temp token', e, s);
      return Response(statusCode: HttpStatus.badRequest);
    }
  }

  /// Handles token refreshing.
  ///
  /// Expects a JSON body with `refresh_token`.
  Future<Response> refresh(RequestContext context) async {
    try {
      final contentLength = int.tryParse(
        context.request.headers['content-length'] ?? '',
      );
      if (contentLength == null || contentLength > _maxAuthContentLength) {
        _logger.info('Refresh failed: bad payload size ($contentLength)');
        return Response(statusCode: HttpStatus.badRequest);
      }

      final body = await context.request.json() as Map<String, dynamic>;
      final refreshToken = body['refresh_token'] as String?;

      if (refreshToken == null) {
        _logger.info('Refresh failed: Missing refresh_token');
        return Response(statusCode: HttpStatus.badRequest);
      }

      // 1. Validate the refresh token and get its payload
      final payload = await _tokens.getPayload(
        refreshToken,
        isRefreshToken: true,
      );
      final userId = payload.jsonContent['sub'] as String;

      // 2. Verify user still exists
      try {
        await _credentials.storage.getPasswordHash(userId);
      } on UserDoesNotExistException {
        _logger.info('Refresh failed: User does not exist ($userId)');
        return Response(statusCode: HttpStatus.unauthorized);
      }

      // 3. Fetch fresh roles
      final roles = await _getUserRoles(userId);

      // 4. Exchange for new tokens
      final tokens = await _tokens.newAccessToken(
        refreshToken,
        extraClaims: {'roles': roles},
      );

      return Response.json(body: tokens);
    } on FormatException catch (e) {
      _logger.info('Refresh failed: Invalid JSON format', e);
      return Response(statusCode: HttpStatus.badRequest);
    } on RefreshTokenInvalid catch (e) {
      _logger.info('Refresh failed: Invalid refresh token', e);
      return Response(statusCode: HttpStatus.unauthorized);
    } catch (e, s) {
      _logger.severe('Refresh failed: Internal error', e, s);
      return Response(statusCode: HttpStatus.internalServerError);
    }
  }

  /// Handles user logout.
  ///
  /// Invalidates the refresh token associated with the current user.
  Future<Response> logout(RequestContext context) async {
    try {
      final user = context.read<User>();
      final serial = user.metadata['serial'] as String?;
      if (serial == null) {
        _logger.info('Logout failed: Missing token serial');
        return Response(statusCode: HttpStatus.unauthorized);
      }
      await _tokens.invalidateRefreshToken(serial, user.id, 0);
      return Response(statusCode: HttpStatus.noContent);
    } catch (e, s) {
      _logger.warning('Logout failed', e, s);
      return Response(statusCode: HttpStatus.unauthorized);
    }
  }
}
