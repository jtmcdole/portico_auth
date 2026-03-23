import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:clock/clock.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';

import 'exceptions.dart';
import 'models.dart';
import 'token_storage.dart';
import 'in_memory_token_storage.dart';
import 'network.dart';

void _emptyCallback(AuthState _) {}

/// The client-side SDK for the Dart Auth Service.
class AuthClient {
  final TokenStorage _storage;
  final AuthNetworkClient _network;
  final Clock _clock;
  final Random _random;

  var _refreshCompleter = Completer<void>.sync()..complete();
  TokenSet? _cachedTokens;
  DateTime? _refreshDeadline;
  late final Future<void> _initFuture;

  /// Creates a new [AuthClient].
  ///
  /// [storage] is the storage adapter for persisting tokens. Defaults to [InMemoryTokenStorage].
  /// [client] is the [http.Client] to use for network requests.
  AuthClient({
    required Uri loginUrl,
    required Uri registerUrl,
    required Uri refreshUrl,
    required Uri logoutUrl,
    required Uri updatePasswordUrl,
    TokenStorage? storage,
    http.Client? client,
    this.onAuthStateChanged = _emptyCallback,
    @visibleForTesting AuthNetworkClient? networkClient,
    @visibleForTesting Clock clock = const Clock(),
    @visibleForTesting Random? random,
  }) : _storage = storage ?? InMemoryTokenStorage(),
       _network =
           networkClient ??
           AuthNetworkClient(
             client ?? http.Client(),
             loginUrl: loginUrl,
             registerUrl: registerUrl,
             refreshUrl: refreshUrl,
             logoutUrl: logoutUrl,
             updatePasswordUrl: updatePasswordUrl,
             needsClosing: client == null,
           ),
       _clock = clock,
       _random = random ?? Random() {
    _updateState(const Unauthenticated());
    _initFuture = _initialize();
  }

  /// The current state value.
  AuthState get state => _state;
  AuthState _state = const Unauthenticated();

  /// A future that completes when the client has finished initializing.
  @visibleForTesting
  Future<void> get ready => _initFuture;

  /// The current authentication state.
  Function(AuthState) onAuthStateChanged;

  /// Logs in with [userId] and [password].
  Future<void> login(String userId, String password) async {
    await _initFuture;
    _updateState(const Authenticating());
    try {
      final tokensMap = await _network.login(userId, password);
      final tokens = TokenSet.fromJson(tokensMap);
      await _saveTokens(tokens);
      final user = _userFromToken(tokens.accessToken);
      _updateState(Authenticated(user));
    } catch (e) {
      _updateState(const Unauthenticated());
      rethrow;
    }
  }

  /// Registers a new user with [userId] and [password].
  ///
  /// [login] should be called after registering to get new tokens.
  Future<void> register(String userId, String password) async {
    await _network.register(userId, password);
  }

  /// Updates the user's password and logs them out.
  ///
  /// This requires the server to support the update password endpoint.
  Future<void> updatePassword(String oldPassword, String newPassword) async {
    if (state is! Authenticated) {
      throw const AuthNotAuthenticatedException();
    }

    await _network.updatePassword(oldPassword, newPassword);

    // Force local logout without server notification, as tokens are already invalidated
    _cachedTokens = null;
    _refreshDeadline = null;
    await _storage.clear();
    _cancelRefresh();
    _updateState(const Unauthenticated());
  }

  /// Logs out the current user.
  Future<void> logout() async {
    final tokensToInvalidate = _cachedTokens;
    _cachedTokens = null;
    _refreshDeadline = null;
    await _storage.clear();

    _cancelRefresh();
    await _initFuture;

    // Attempt to invalidate on server best-effort
    if (tokensToInvalidate != null) {
      try {
        await _network.logout(tokensToInvalidate.refreshToken);
      } catch (_) {
        // Ignore network errors on logout
      }
    }

    _updateState(const Unauthenticated());
  }

  /// Returns the authorization headers for making authenticated requests.
  ///
  /// Handles token refresh automatically based on expiration proximity.
  Future<Map<String, String>> httpHeaders() async {
    await _initFuture;

    if (_state is! Authenticated) {
      throw const AuthNotAuthenticatedException();
    }

    final tokens = _cachedTokens;
    final deadline = _refreshDeadline;

    if (tokens == null || deadline == null) {
      _updateState(const Unauthenticated());
      throw const AuthNotAuthenticatedException();
    }

    final now = _clock.now();

    // Critical Point: Less than 5 minutes remaining.
    // Must wait for refresh to ensure validity.
    final criticalPoint = tokens.expirationDate.subtract(
      const Duration(minutes: 5),
    );
    if (now.isAfter(criticalPoint)) {
      await _performRefresh();
      return {'Authorization': 'Bearer ${_cachedTokens!.accessToken}'};
    }

    // Grace Period: Past the randomized deadline, but safe enough (more than 5 mins left).
    // Trigger refresh in background, but return current token immediately.
    if (now.isAfter(deadline)) {
      _performRefresh().ignore();
    }

    return {'Authorization': 'Bearer ${tokens.accessToken}'};
  }

  /// Disposes resources.
  void close() {
    _cancelRefresh();
    _network.close();
  }

  Future<void> _initialize() async {
    final tokens = await _storage.load();
    if (tokens != null) {
      // Restore state
      try {
        final user = _userFromToken(tokens.accessToken);
        _cachedTokens = tokens;
        _calculateDeadline(tokens);
        _updateState(Authenticated(user));

        // Check if we need a refresh immediately
        if (_clock.now().isAfter(_refreshDeadline!)) {
          _performRefresh().ignore();
        }
      } catch (_) {
        await _storage.clear();
        _cachedTokens = null;
        _updateState(const Unauthenticated());
      }
    }
  }

  void _updateState(AuthState newState) {
    if (_state != newState) {
      _state = newState;
      onAuthStateChanged(newState);
    }
  }

  Future<void> _saveTokens(TokenSet tokens) async {
    _cachedTokens = tokens;
    _calculateDeadline(tokens);
    await _storage.save(tokens);
  }

  void _calculateDeadline(TokenSet tokens) {
    // Random jitter between 5 and 12 minutes before expiration
    final jitterMs = _random.nextInt(7 * 60 * 1000) + 5 * 60 * 1000;
    _refreshDeadline = tokens.expirationDate.subtract(
      Duration(milliseconds: jitterMs),
    );
  }

  void _cancelRefresh() {
    if (!_refreshCompleter.isCompleted) {
      _refreshCompleter.completeError(const AuthNotAuthenticatedException());
    }
  }

  /// The single entry point for refreshing tokens.
  /// Coalesces multiple requests into one network call.
  Future<void> _performRefresh() {
    // If a refresh is already in progress, wait for it.
    if (!_refreshCompleter.isCompleted) {
      return _refreshCompleter.future;
    }

    final tokens = _cachedTokens;
    if (tokens == null) {
      return Future.error(const AuthNotAuthenticatedException());
    }

    final completer = _refreshCompleter = Completer<void>();

    // Start background refresh logic
    () async {
      try {
        final newTokensMap = await _network.refresh(tokens.refreshToken);
        final newTokens = TokenSet.fromJson(newTokensMap);
        await _saveTokens(newTokens);
        final user = _userFromToken(newTokens.accessToken);
        _updateState(Authenticated(user));
        if (!completer.isCompleted) completer.complete();
      } catch (e) {
        // If refresh failed with invalid credentials or we are past absolute expiration, logout.
        if (e is AuthInvalidCredentialsException) {
          await logout();
          if (!completer.isCompleted) {
            completer.completeError(const AuthNotAuthenticatedException());
          }
        } else {
          // Transient error, just complete error
          if (!completer.isCompleted) completer.completeError(e);
        }
      }
    }();

    return completer.future;
  }

  AuthUser _userFromToken(String accessToken) {
    final parts = accessToken.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid JWT');
    }
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );

    final List<UserRole> roles = [];
    if (payload['roles'] case List rolesList) {
      for (final roleData in rolesList) {
        if (roleData case {'role': String role}) {
          roles.add(UserRole(role: role, scope: roleData['scope'] as String?));
        }
      }
    }

    if (payload case {'sub': String userId, 'name': String? name}) {
      return AuthUser(id: userId, name: name, roles: roles);
    }

    throw AuthUnknownException('Could not parse user from token');
  }
}
