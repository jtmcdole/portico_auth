import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:jose_plus/jose.dart';

void main() async {
  print('--- Token Management Example ---');

  // 1. Generate Keys
  // NOTE: IN PRODUCTION, LOAD THESE SECURELY!
  final signingKey = JsonWebKey.generate(JsonWebAlgorithm.es384.name);
  final encryptingKey = JsonWebKey.generate(JsonWebAlgorithm.a128kw.name);

  // 2. Initialize Storage
  final storage = AuthTokensInMemoryStorage();

  // 3. Initialize Manager
  final manager = AuthTokensManager(
    signingKey,
    encryptingKey,
    storage,
    issuer: 'https://api.myapp.com',
    audience: 'https://app.myapp.com',
  );

  // 4. Mint Tokens
  print('Minting tokens for user@example.com...');
  final tokens = await manager.mintTokens('user@example.com');
  final accessToken = tokens.accessToken;
  final refreshToken = tokens.refreshToken;

  print('Access Token (JWT): ${accessToken.substring(0, 20)}...');
  print('Refresh Token (JWE): ${refreshToken.substring(0, 20)}...');

  // 5. Validate Access Token
  print('\nVerifying Access Token...');
  try {
    final record = await manager.validateToken(accessToken);
    print('Token Valid! User: ${record.userId}, Serial: ${record.serial}');
  } catch (e) {
    print('Validation failed: $e');
  }

  // 6. Refresh Tokens
  print('\nExchanging Refresh Token...');
  try {
    final newTokens = await manager.newAccessToken(refreshToken);
    print('Refresh Successful!');
    print('New Access Token: ${(newTokens.accessToken).substring(0, 20)}...');
  } catch (e) {
    print('Refresh failed: $e');
  }
}
