# Portico Auth Tokens

[![Portico Auth Tokens](https://img.shields.io/badge/Portico_Auth-Tokens-blue?style=for-the-badge&logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

<div style="text-align: center;">
<img src="../../assets/logo.svg" width="300" alt="Description of the image" />
</div>


Core logic for minting and validating JWT Access Tokens and JWE Refresh Tokens. This package handles the cryptographic heavy lifting of the Portico Auth ecosystem, ensuring tokens are signed, encrypted, and rotated securely.

## Features

- **JWT/JWS:** Signed access tokens for stateless, high-performance authorization.
- **JWE:** Encrypted refresh tokens using JSON Web Encryption for secure long-term sessions.
- **Automatic Rotation:** Built-in support for refresh token rotation and replay attack detection to prevent session hijacking.
- **Temporary Tokens:** Generate short-lived, single-use tokens for specific API actions or multi-factor flows, e.g. websocket or webpush authentication.

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  portico_auth_tokens: ^1.0.0
```

## Interactive Web Simulator

Experience the full capabilities of the Portico Auth ecosystem without setting up a backend. The **Web Simulator** runs the entire stack (Client, Server, and Storage) directly in your browser.

- **[Run the Web Simulator](https://jtmcdole.github.io/auth_simulator)**

## Usage

### 1. Initialize the Manager

The `AuthTokensManager` requires a signing key for JWTs and an encrypting key for JWEs.

> [!IMPORTANT]
> You should ensure these keys are securly stored at rest.

```dart
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:jose_plus/jose.dart';

void main() async {
  // Generate or Load Keys (Load from secure storage in production!)
  final signingKey = JsonWebKey.generate(JsonWebAlgorithm.es256.name);
  final encryptingKey = JsonWebKey.generate(JsonWebAlgorithm.a128kw.name);

  // Initialize Storage (e.g., Memory, SQLite, or YAML)
  final storage = AuthTokensInMemoryStorage();

  final manager = AuthTokensManager(
    signingKey,
    encryptingKey,
    storage,
    issuer: 'https://api.myapp.com',
    audience: 'https://app.myapp.com',
  );
}
```

### 2. Minting Tokens

Typically called after a successful login.

```dart
final tokens = await manager.mintTokens('user@example.com');
print('Access Token: ${tokens['access_token']}');
print('Refresh Token: ${tokens['refresh_token']}');
```

### 3. Validating Access Tokens

Validates the signature, expiration, and claims of a JWT.

```dart
try {
  final record = await manager.validateToken(tokens['access_token']);
  print('Valid request from: ${record.userId}');
} catch (e) {
  print('Invalid token: $e');
}
```

### 4. Refreshing Sessions

Exchange a JWE refresh token for a new set of tokens.

> [!NOTE]
> The refresh token is updated during this process. If end user tokens are
> used multiple times, they will be immediately invalidated. However, your API
> endpoints may not know about the invalidation. Broadcasting that is outside
> the scope of this package at this time.

```dart
try {
  final newTokens = await manager.newAccessToken(tokens['refresh_token']);
  print('New Access Token minted.');
} catch (e) {
  print('Refresh failed (possibly revoked or replayed): $e');
}
```

## Examples

- **[Token Management Example](../../packages/portico_auth_tokens/example/main.dart):** Comprehensive example covering key generation, minting, validation, and refreshing.
