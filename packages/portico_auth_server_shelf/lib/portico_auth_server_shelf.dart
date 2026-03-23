/// An example implementation of using [AuthTokensManager] with Shelf handlers.
library;

import 'dart:convert';

import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart'
    show AuthTokensManager, RefreshTokenInvalid, TokenSet, TokenRecord;
import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import 'src/exceptions.dart';
export 'src/exceptions.dart';

/// Shelf based Portico Authentication handlers.
class AuthShelf {
  /// Logger for this server.
  static final log = Logger('auth.shelf');

  /// The token manager for minting and validating JWTs.
  final AuthTokensManager tokens;

  /// The credentials manager for user registration and verification.
  final AuthCredentialsManager credentials;

  /// The role manager for managing user roles.
  final AuthRoleManager roles;

  /// The maximum content-length for any auth body.
  final int _maxAuthContentLength;

  /// Creates a new [AuthShelf].
  AuthShelf(
    this.tokens, {
    required this.credentials,
    required this.roles,
    int maxAuthContentLength = 10240,
  }) : _maxAuthContentLength = maxAuthContentLength;

  /// Handles user registration requests.
  ///
  /// Expects a JSON body with `user_id` and `password`.
  Future<Response> register(Request request) async {
    try {
      final contentLength = request.contentLength;
      if (contentLength == null || contentLength > _maxAuthContentLength) {
        log.warning('Registration failed: bad payload size ($contentLength)');
        return Response.badRequest(body: 'Invalid payload size');
      }

      final body = await request.readAsString();
      final data = jsonDecode(body);

      if (data case {'user_id': String userId, 'password': String password}) {
        await credentials.registerUser(userId, password);
        return Response(201);
      }
      return Response.badRequest(body: 'Missing user_id or password');
    } on FormatException catch (e) {
      log.warning('Invalid JSON in registration request: $e');
      return Response.badRequest(body: 'Invalid JSON');
    } on UserAlreadyExistsException catch (e) {
      log.warning('Registration failed: user already exists: $e');
      return Response(409, body: 'User already exists');
    } on InvalidCredentialsException catch (e) {
      log.warning('Registration failed: $e');
      return Response(
        403,
        body: '{"error": "user_id or password does not meet requirements"}',
      );
    } catch (e) {
      log.severe('Unexpected error during registration: $e');
      return Response.internalServerError();
    }
  }

  /// Handles updating the password.
  ///
  /// Expects a JSON body with `user_id`, `old_password`, and `new_password`.
  Future<Response> updatePassword(Request request) async {
    try {
      final context = request.context;
      if (!context.containsKey('portico-token')) {
        throw UnauthorizedException('Unauthenticated request');
      }

      if (context['portico-token'] case TokenRecord token) {
        final contentLength = request.contentLength;

        if (contentLength == null || contentLength > _maxAuthContentLength) {
          log.warning(
            'Update password failed: bad payload size ($contentLength)',
          );
          return Response.badRequest(body: 'Invalid payload size');
        }

        final body = await request.readAsString();
        final data = jsonDecode(body);

        if (data case {
          'old_password': String oldPassword,
          'new_password': String newPassword,
        }) {
          await credentials.updatePassword(
            token.userId,
            oldPassword,
            newPassword,
          );
          await tokens.invalidateAllRefreshTokens(token.userId);
          return Response(204);
        }
        return Response.badRequest(
          body: 'Missing old_password or new_password',
        );
      }
      return Response.unauthorized('Invalid credentials');
    } on FormatException catch (e) {
      log.warning('Invalid JSON in update password request: $e');
      return Response.badRequest(body: 'Invalid JSON');
    } on UserDoesNotExistException catch (e) {
      log.warning('Update password failed: user not found: $e');
      return Response.unauthorized('User not found');
    } on InvalidCredentialsException catch (e) {
      log.warning('Update password failed: invalid credentials: $e');
      return Response.unauthorized('Invalid credentials');
    } catch (e) {
      log.severe('Unexpected error during update password: $e');
      return Response.internalServerError();
    }
  }

  /// Handles user login requests.
  ///
  /// Expects a JSON body with `user_id` and `password`.
  /// Returns a [TokenSet] as JSON on success.
  Future<Response> login(Request request) async {
    try {
      final contentLength = request.contentLength;
      if (contentLength == null || contentLength > _maxAuthContentLength) {
        log.warning('Login failed: bad payload size ($contentLength)');
        return Response.badRequest(body: 'Invalid payload size');
      }

      final body = await request.readAsString();
      final data = jsonDecode(body);

      if (data case {'user_id': String userId, 'password': String password}) {
        try {
          await credentials.verifyCredentials(userId, password);

          // Fetch roles
          final roles = await _getUserRoles(userId);

          final tokens = await this.tokens.mintTokens(
            userId,
            extraClaims: {'roles': roles},
          );
          return Response.ok(
            jsonEncode(tokens),
            headers: {'content-type': 'application/json'},
          );
        } on UserDoesNotExistException catch (e) {
          log.warning('Login failed: user does not exist: $e');
          return Response.unauthorized('Invalid user_id or password');
        } on InvalidCredentialsException catch (e) {
          log.warning('Login failed: invalid credentials: $e');
          return Response.unauthorized('Invalid user_id or password');
        }
      }
      return Response.badRequest(body: 'Missing user_id or password');
    } on FormatException catch (e) {
      log.warning('Invalid JSON in login request: $e');
      return Response.badRequest(body: 'Invalid JSON');
    } catch (e) {
      log.severe('Unexpected error during login: $e');
      return Response.internalServerError();
    }
  }

  /// Shelf middleware for checking user tokens.
  ///
  /// Extracts the Bearer token from the `Authorization` header, validates it,
  /// and attaches the payload to the request context.
  Handler middleware(Handler innerHandler) {
    return (Request request) async {
      String? auth =
          request.headers['authorization'] ??
          request.url.queryParameters['authorization'];
      if (auth == null) return Response.unauthorized(null);
      if (!auth.startsWith('Bearer ')) return Response.unauthorized(null);
      auth = auth.substring(7).trim();
      try {
        final token = await tokens.validateToken(auth);
        final payload = token.claims;

        request = request.change(
          context: {'jwt': payload, 'portico-token': token, 'auth': auth},
        );
        log.info('user [${payload['sub']}] authorized for [${request.url}]');
        // now, we could validate that the user is in our database;
        // or we could also track the serial number this AT was generated with
        // and see if it exists in the database; but we'd be doing that for
        // every API call.
      } catch (e) {
        log.warning('error while checking authorization: $e');
        return Response.unauthorized(null);
      }
      return innerHandler(request);
    };
  }

  /// Generates a temporary token that can be used to authenticate requests.
  Future<Response> generateTempToken(Request request) async {
    if (request.context case {'auth': String auth}) {
      final jwt = await tokens.generateTempToken(auth);
      return Response.ok(jwt, headers: {'Content-type': 'application/jwt'});
    }
    return Response.badRequest();
  }

  /// Handle exchanging a refresh token for an access token.
  ///
  /// Since this can be called after the access token has expired, it should be
  /// from a unauthed router call.
  ///
  /// A new refresh token will be returned to the user.
  Future<Response> refresh(Request request) async {
    try {
      if (!(request.headers['content-type'] ?? '').startsWith(
        'application/json',
      )) {
        return Response.badRequest(body: 'Bad Request');
      }

      final contentLength = request.contentLength;
      if (contentLength == null || contentLength > _maxAuthContentLength) {
        log.warning('Refresh failed: bad payload size ($contentLength)');
        return Response.badRequest(body: 'Invalid payload size');
      }

      final data = jsonDecode(await request.readAsString());
      if (data case {'refresh_token': String refreshToken}) {
        // 1. Validate the refresh token and get its payload
        final payload = await this.tokens.getPayload(
          refreshToken,
          isRefreshToken: true,
        );
        final userId = payload.jsonContent['sub'] as String;

        // 2. Verify user still exists
        try {
          await credentials.storage.getPasswordHash(userId);
        } on UserDoesNotExistException {
          log.warning('Token refresh failed: user $userId no longer exists');
          return Response.unauthorized('User no longer exists');
        }

        // 3. Fetch fresh roles
        final roles = await _getUserRoles(userId);

        // 4. Exchange for new tokens
        final tokens = await this.tokens.newAccessToken(
          refreshToken,
          extraClaims: {'roles': roles},
        );
        return Response.ok(
          json.encode(tokens),
          headers: {'Content-type': 'application/json'},
        );
      }
      return Response.badRequest();
    } on RefreshTokenInvalid catch (e) {
      log.warning('error handling access token refresh: $e');
      return Response.unauthorized(e.reason);
    } catch (e) {
      log.warning('error handling access token refresh: $e');
      return Response.badRequest();
    }
  }

  /// Invalidate a refresh token, for example when the user logs out of the service.
  Future<Response> logout(Request request) async {
    try {
      if (!(request.headers['content-type'] ?? '').startsWith(
        'application/json',
      )) {
        return Response.badRequest(body: 'Bad Request');
      }

      final contentLength = request.contentLength;
      if (contentLength == null || contentLength > _maxAuthContentLength) {
        log.warning('Invalidation failed: bad payload size ($contentLength)');
        return Response.badRequest(body: 'Invalid payload size');
      }

      final data = jsonDecode(await request.readAsString());
      if (data case {'refresh_token': String refreshToken}) {
        final payload = await tokens.getPayload(
          refreshToken,
          isRefreshToken: true,
        );
        final content = payload.jsonContent;
        if (content case {
          'serial': String serial,
          'counter': num counter,
          'sub': String userId,
        }) {
          await tokens.invalidateRefreshToken(serial, userId, counter);
          return Response.ok(null);
        }
      }
      return Response.badRequest();
    } on RefreshTokenInvalid catch (e) {
      log.warning('error handling access token refresh: $e');
      return Response.unauthorized(e.reason);
    } catch (e) {
      log.warning('error handling access token refresh: $e');
      return Response.badRequest();
    }
  }

  Future<List<Map<String, dynamic>>> _getUserRoles(
    String userId, {
    bool includeInactive = false,
  }) async {
    final assignments = await this.roles.getUserAssignments(userId);
    final roles = {
      for (final r in await this.roles.listRoles(
        includeInactive: includeInactive,
      ))
        r.name,
    };
    return [
      for (final a in assignments)
        if (roles.contains(a.roleName)) {'role': a.roleName, 'scope': a.scope},
    ];
  }

  /// Middleware to catch exceptions and return 401/403/500.
  Handler exceptionRequestHandler(Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } on ForbiddenException catch (e) {
        log.warning('Access denied: $e');
        return Response.forbidden('$e');
      } on UnauthorizedException catch (e) {
        log.warning('Access denied: $e');
        return Response.unauthorized('$e');
      } catch (e, s) {
        log.warning('Internal error: $e\n$s');
        return Response.internalServerError();
      }
    };
  }

  /// Helper to enforce role requirements within a handler.
  ///
  /// Throws [ForbiddenException]/[UnauthorizedException] if the requirement
  /// is not met. Ensure [exceptionRequestHandler] is used in the pipeline to
  /// catch this.
  void requiredRole(Request request, String role, {String? scope}) {
    final context = request.context;
    if (!context.containsKey('jwt')) {
      throw UnauthorizedException('Unauthenticated request');
    }

    if (context['jwt'] case Map<String, dynamic> payload) {
      final roles = payload['roles'];
      if (roles is List) {
        for (final assignment in roles) {
          if (assignment case {'role': String r, 'scope': String? s}) {
            if (r == role && s == scope) {
              return; // Authorized
            }
          }
        }
      }
    }
    throw ForbiddenException(
      'Insufficient permissions: missing role $role${scope != null ? ' for scope $scope' : ''}',
    );
  }
}
