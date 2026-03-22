import 'dart:convert';
import 'package:portico_auth_client/portico_auth_client.dart';
import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_shelf/portico_auth_server_shelf.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:portico_auth_storage_yaml/portico_auth_storage_yaml.dart';
import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jose_plus/jose.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

import 'virtual_http_client.dart';

class TrafficEntry {
  final DateTime timestamp;
  final String method;
  final Uri url;
  final Map<String, String> requestHeaders;
  final String? requestBody;
  final int statusCode;
  final Map<String, String> responseHeaders;
  final String? responseBody;

  TrafficEntry({
    required this.timestamp,
    required this.method,
    required this.url,
    required this.requestHeaders,
    this.requestBody,
    required this.statusCode,
    required this.responseHeaders,
    this.responseBody,
  });
}

class VisualTokenStorage implements TokenStorage {
  final InMemoryTokenStorage _inner = InMemoryTokenStorage();
  final VoidCallback onUpdate;

  VisualTokenStorage({required this.onUpdate});

  @override
  Future<void> save(TokenSet tokens) async {
    await _inner.save(tokens);
    onUpdate();
  }

  @override
  Future<TokenSet?> load() async {
    return _inner.load();
  }

  @override
  Future<void> clear() async {
    await _inner.clear();
    onUpdate();
  }

  Future<TokenSet?> loadTokens() => _inner.load();
}

class InsecureHash implements HashAdapter {
  final _uuid = const Uuid();

  @override
  Future<List<int>> salt() async => _uuid.v4obj().toBytes();

  @override
  Future<List<int>> hash(String password, List<int> salt) async {
    final hmac = Hmac(sha1, salt);
    final bytes = utf8.encode(password);
    final digest = hmac.convert(bytes);
    return digest.bytes;
  }
}

class SimulatedEnvironment extends ChangeNotifier {
  late AuthTokensYaml tokensStorage;
  late AuthCredentialsYaml credentialsStorage;
  late AuthRolesYaml rolesStorage;
  late VisualTokenStorage clientStorage;

  late AuthTokensManager tokensManager;
  late AuthCredentialsManager credentials;
  late AuthRoleManager roleManager;
  late AuthShelf serverShelf;

  late AuthClient authClient;

  DateTime _currentTime = DateTime(2025, 12, 28, 12, 0, 0);
  DateTime get currentTime => _currentTime;

  final List<TrafficEntry> _traffic = [];
  List<TrafficEntry> get traffic => List.unmodifiable(_traffic);

  final List<LogRecord> _logs = [];
  List<LogRecord> get logs => List.unmodifiable(_logs);

  bool get isAuthenticated => authClient.state is Authenticated;
  String? get userId => (authClient.state as Authenticated?)?.user.id;

  String _tokensYaml = '';
  String _credentialsYaml = '';
  String _rolesYaml = '';

  SimulatedEnvironment() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      _logs.add(record);
      Future.microtask(notifyListeners);
    });
    _init();
  }

  void _init() {
    _logs.clear();

    // Load initial YAML from localStorage if available
    _tokensYaml =
        web.window.localStorage.getItem('portico_auth_simulator_tokens') ?? '';
    _credentialsYaml =
        web.window.localStorage.getItem('portico_auth_simulator_credentials') ??
        '';
    _rolesYaml =
        web.window.localStorage.getItem('portico_auth_simulator_roles') ?? '';

    try {
      tokensStorage = AuthTokensYaml(
        yaml: _tokensYaml.isEmpty ? null : _tokensYaml,
      );
    } catch (e) {
      debugPrint('Error loading tokens storage: $e. Clearing.');
      _tokensYaml = '';
      web.window.localStorage.removeItem('portico_auth_simulator_tokens');
      tokensStorage = AuthTokensYaml();
    }
    tokensStorage.onYamlUpdate = (yaml) {
      _tokensYaml = yaml;
      notifyListeners();
    };

    try {
      credentialsStorage = AuthCredentialsYaml(
        yaml: _credentialsYaml.isEmpty ? null : _credentialsYaml,
      );
    } catch (e) {
      debugPrint('Error loading credentials storage: $e. Clearing.');
      _credentialsYaml = '';
      web.window.localStorage.removeItem('portico_auth_simulator_credentials');
      credentialsStorage = AuthCredentialsYaml();
    }
    credentialsStorage.onYamlUpdate = (yaml) {
      _credentialsYaml = yaml;
      notifyListeners();
    };

    try {
      rolesStorage = AuthRolesYaml(
        yaml: _rolesYaml.isEmpty ? null : _rolesYaml,
      );
    } catch (e) {
      debugPrint('Error loading roles storage: $e. Clearing.');
      _rolesYaml = '';
      web.window.localStorage.removeItem('portico_auth_simulator_roles');
      rolesStorage = AuthRolesYaml();
    }
    rolesStorage.onYamlUpdate = (yaml) {
      _rolesYaml = yaml;
      notifyListeners();
    };

    clientStorage = VisualTokenStorage(onUpdate: notifyListeners);

    final signingKey = JsonWebKey.fromJson({
      'kty': 'oct',
      'k': 'GawgguFyGrWKav7AX4VKUg',
      'alg': 'HS256',
    })!;
    final encryptingKey = JsonWebKey.fromJson({
      'kty': 'oct',
      'k': 'AyM1SysPpbyD2Il83D7O6A',
      'alg': 'A128KW',
    })!;

    tokensManager = AuthTokensManager(
      signingKey,
      encryptingKey,
      tokensStorage,
      issuer: 'https://example.com',
      audience: 'example-app',
      // ignore: invalid_use_of_visible_for_testing_member
      clock: Clock(() => _currentTime),
    );

    credentials = AuthCredentialsManager(
      storage: credentialsStorage,
      hasher: InsecureHash(),
    );
    roleManager = AuthRoleManager(rolesStorage);

    loadClientTokens();

    serverShelf = AuthShelf(
      tokensManager,
      credentials: credentials,
      roles: roleManager,
    );

    final virtualClient = VirtualHttpClient((request) async {
      return _routeRequest(request);
    });

    final apiUri = Uri.parse('https://api.example.com/');
    authClient = AuthClient(
      loginUrl: apiUri.resolve('login'),
      registerUrl: apiUri.resolve('register'),
      refreshUrl: apiUri.resolve('refresh'),
      logoutUrl: apiUri.resolve('logout'),
      updatePasswordUrl: apiUri.resolve('update-password'),
      client: virtualClient,
      storage: clientStorage,
      onAuthStateChanged: (_) => notifyListeners(),
      // ignore: invalid_use_of_visible_for_testing_member
      clock: Clock(() => _currentTime),
    );
  }

  Future<shelf.Response> _routeRequest(shelf.Request request) async {
    final startTime = _currentTime;
    final requestBody = await request.readAsString();

    final shelfRequest = shelf.Request(
      request.method,
      request.requestedUri,
      headers: request.headers,
      body: requestBody,
      context: request.context,
    );

    late shelf.Response response;
    final path = request.url.path;
    final normalized = path.startsWith('/') ? path.substring(1) : path;

    if (normalized.endsWith('register')) {
      response = await serverShelf.register(shelfRequest);
    } else if (normalized.endsWith('login')) {
      response = await serverShelf.login(shelfRequest);
    } else if (normalized.endsWith('update-password')) {
      response = await serverShelf.updatePassword(shelfRequest);
    } else if (normalized.endsWith('refresh')) {
      response = await serverShelf.refresh(shelfRequest);
    } else if (normalized.endsWith('logout')) {
      response = await serverShelf.logout(shelfRequest);
    } else if (normalized.endsWith('protected')) {
      response = await serverShelf.middleware((req) async {
        return shelf.Response.ok(
          '{"message": "Success! You accessed protected data."}',
        );
      })(shelfRequest);
    } else if (normalized.endsWith('scoped')) {
      response = await serverShelf.middleware((req) async {
        try {
          serverShelf.requiredRole(req, 'admin');
          return shelf.Response.ok('{"message": "Welcome, Admin!"}');
        } on shelf.Response catch (e) {
          return e;
        } catch (e) {
          return shelf.Response.forbidden(e.toString());
        }
      })(shelfRequest);
    } else {
      response = shelf.Response.notFound('Not Found: $path');
    }

    final responseBody = await response.readAsString();

    _traffic.add(
      TrafficEntry(
        timestamp: startTime,
        method: request.method,
        url: request.url,
        requestHeaders: request.headers,
        requestBody: requestBody,
        statusCode: response.statusCode,
        responseHeaders: response.headers,
        responseBody: responseBody,
      ),
    );

    notifyListeners();

    return shelf.Response(
      response.statusCode,
      body: responseBody,
      headers: response.headers,
      context: response.context,
    );
  }

  Future<http.Response> get(Uri url) async {
    final headers = await authClient.httpHeaders();
    final virtualClient = VirtualHttpClient(
      (request) => _routeRequest(request),
    );
    return virtualClient.get(url, headers: headers);
  }

  void advanceTime(Duration duration) {
    _currentTime = _currentTime.add(duration);
    notifyListeners();
  }

  void reset() {
    web.window.localStorage.removeItem('portico_auth_simulator_tokens');
    web.window.localStorage.removeItem('portico_auth_simulator_credentials');
    web.window.localStorage.removeItem('portico_auth_simulator_roles');
    _init();
    _traffic.clear();
    _currentTime = DateTime(2025, 12, 28, 12, 0, 0);
    notifyListeners();
  }

  void saveState() {
    web.window.localStorage.setItem('portico_auth_simulator_roles', _rolesYaml);
    web.window.localStorage.setItem(
      'portico_auth_simulator_tokens',
      _tokensYaml,
    );
    web.window.localStorage.setItem(
      'portico_auth_simulator_credentials',
      _credentialsYaml,
    );
    notifyListeners();
  }

  void loadState() {
    _init();
    notifyListeners();
  }

  void saveClientTokens() {
    clientStorage.loadTokens().then((tokens) {
      if (tokens != null) {
        web.window.localStorage.setItem(
          'portico_auth_client_tokens',
          jsonEncode(tokens.toJson()),
        );
      }
    });
  }

  void loadClientTokens() {
    final saved = web.window.localStorage.getItem('portico_auth_client_tokens');
    if (saved != null) {
      try {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        final tokens = TokenSet.fromJson(data);
        clientStorage.save(tokens);
      } catch (e) {
        debugPrint('Error loading client tokens: $e');
      }
    }
  }

  void clearClientTokens() {
    clientStorage.clear();
  }

  // Role Management
  Future<void> createRole(
    String name,
    String displayName,
    String description,
  ) async {
    await roleManager.createRole(
      name: name,
      displayName: displayName,
      description: description,
    );
    notifyListeners();
  }

  Future<void> toggleRoleStatus(String name, bool isActive) async {
    if (isActive) {
      await roleManager.activateRole(name);
    } else {
      await roleManager.deactivateRole(name);
    }
    notifyListeners();
  }

  Future<void> assignRole(
    String userId,
    String roleName, {
    String? scope,
  }) async {
    await roleManager.assignRoleToUser(
      userId: userId,
      roleName: roleName,
      scope: scope,
    );
    notifyListeners();
  }

  Future<void> unassignRole(
    String userId,
    String roleName, {
    String? scope,
  }) async {
    await roleManager.unassignRoleFromUser(
      userId: userId,
      roleName: roleName,
      scope: scope,
    );
    notifyListeners();
  }

  Future<void> revokeSession(String serial, String userId) async {
    await tokensStorage.invalidateRefreshToken(serial: serial, userId: userId);
    notifyListeners();
  }

  // --- UI Inspection Getters ---

  Map<String, UserCredential> get users => credentialsStorage.credentials;

  Map<String, Credential> get tokens => tokensStorage.memory;

  Map<String, Role> get roles => rolesStorage.roles;

  List<RoleAssignment> get assignments => rolesStorage.assignments;
}
