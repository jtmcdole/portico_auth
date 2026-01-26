import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_frog/portico_auth_server_frog.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:jose_plus/jose.dart';

// Note: This is a conceptual example of how to use AuthFrog
// In a real Dart Frog project, these handlers would be placed in the routes/ folder.

void main() async {
  print('--- Portico Auth Server Frog Example ---');
  print('This example demonstrates the configuration of AuthFrog.');

  // 1. Setup Dependencies
  final signingKey = JsonWebKey.generate(JsonWebAlgorithm.es256.name);
  final encryptingKey = JsonWebKey.generate(JsonWebAlgorithm.a128kw.name);

  final tokenManager = AuthTokensManager(
    signingKey,
    encryptingKey,
    AuthTokensInMemoryStorage(),
    issuer: 'https://example.com',
    audience: 'https://example.com',
  );

  final credentials = AuthCredentialsManager(
    storage: AuthCredentialsInMemoryStorage(),
  );

  final roleManager = AuthRoleManager(AuthRolesInMemoryStorage());

  // 2. Initialize Auth Frog
  final authFrog = AuthFrog(
    tokens: tokenManager,
    credentials: credentials,
    roles: roleManager,
  );

  print('AuthFrog initialized for: ${authFrog.runtimeType}');
  print('Usage:');
  print('Use handlers in your routes:');
  print('''
  Future<Response> onRequest(RequestContext context) {
    return authFrog.login(context);
  }
  ''');
}
