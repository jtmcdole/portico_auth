import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_shelf/portico_auth_server_shelf.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:jose_plus/jose.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  // 1. Setup Dependencies (In-Memory for this example)

  // -- Keys --
  // NOTE: IN PRODUCTION, LOAD THESE SECURELY!
  final signingKey = JsonWebKey.generate(JsonWebAlgorithm.es256.name);
  final encryptingKey = JsonWebKey.generate(JsonWebAlgorithm.a128kw.name);

  // -- Tokens --
  final tokenManager = AuthTokensManager(
    signingKey,
    encryptingKey,
    AuthTokensInMemoryStorage(),
    issuer: 'https://example.com',
    audience: 'https://example.com',
  );

  // -- Credentials --
  final credentials = AuthCredentialsManager(
    storage: AuthCredentialsInMemoryStorage(),
  );

  // -- Roles --
  final roleStorage = AuthRolesInMemoryStorage();
  final roleManager = AuthRoleManager(roleStorage);

  // 2. Initialize Auth Server
  final authServer = AuthShelf(
    tokenManager,
    credentials: credentials,
    roles: roleManager,
  );

  // 3. Bootstrap Data
  print('Bootstrapping data...');
  const userId = 'admin@example.com';
  const password = 'password123';

  await credentials.registerUser(userId, password);
  await roleManager.createRole(
    name: 'admin',
    displayName: 'Admin',
    description: 'Super user',
  );
  await roleManager.assignRoleToUser(
    userId: userId,
    roleName: 'admin',
    scope: 'system',
  );
  print('Created user: $userId / $password with role admin (scope: system)');

  // 4. Define Routes
  final auth = Router();
  final open = Router();

  // Public Auth Endpoints
  open.post('/register', authServer.register);
  open.post('/login', authServer.login);
  open.post('/logout', authServer.logout);
  auth.post('/refresh', authServer.refresh);

  // Protected Admin Endpoint
  auth.get('/admin/<system>', (Request request, String system) {
    // Dynamic Role Check: User must be 'admin' for this specific 'system'
    authServer.requiredRole(request, 'admin', scope: system);

    final jwt = request.context['jwt'] as Map<String, dynamic>;
    return Response.ok(
      'Welcome, Admin! You are accessing system: $system\nUser: ${jwt['sub']}',
    );
  });

  // 5. Setup Middleware Pipeline
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(authServer.exceptionRequestHandler) // Handles 401/403
      .addMiddleware(authServer.middleware) // Validates JWT
      .addHandler(auth.call);

  final cascade = Cascade().add(open.call).add(handler);

  // 6. Start Server
  final server = await shelf_io.serve(cascade.handler, 'localhost', 8080);
  print('Server listening on http://${server.address.host}:${server.port}');
  print(
    'Try logging in via POST /login and then accessing /admin/system with the token.',
  );
  print('''
Example with curl:
  curl -X POST http://localhost:8080/login  -H "Content-Type: application/json"  -d '{"user_id":"admin@example.com","password":"password123"}'
  curl -X get http://localhost:8080/admin/system -H 'Authorization: Bearer <ACCESS_TOKEN>'
''');
}
