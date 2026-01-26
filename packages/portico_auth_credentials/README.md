# Portico Auth Credentials

[![Portico Auth Credentials](https://img.shields.io/badge/Portico_Auth-Credentials-blue?style=for-the-badge&logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

<div style="text-align: center;">
<img src="../../assets/logo.svg" width="300" alt="Description of the image" />
</div>

Support for user identity management and hardened credential verification using Argon2id. This package provides the core logic for securely hashing and verifying user passwords.

> [!NOTE]
> Passwords are never stored at rest.

## Features

- **Secure Hashing:** Uses Argon2id for password hashing via `package:cryptography`.
- **Validation:** Built-in validation for password strength (standard and rigid).
- **Storage Agnostic:** Interface-driven design allows for SQLite, YAML, or in-memory backends.
- **Exception Driven:** Clear, descriptive exceptions for common failure modes (InvalidCredentials, UserExists, etc.).

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  portico_auth_credentials: ^1.0.0
```

## Interactive Web Simulator

Experience the full capabilities of the Portico Auth ecosystem without setting up a backend. The **Web Simulator** runs the entire stack (Client, Server, and Storage) directly in your browser.

- **[Run the Web Simulator](https://jtmcdole.github.io/auth_simulator)**

## Usage

### 1. Choose a Storage Adapter

For testing or development, use the in-memory adapter. For production, use a persistent adapter like SQLite or YAML, or provide your own.

```dart
import 'package:portico_auth_credentials/portico_auth_credentials.dart';

final storage = AuthCredentialsInMemoryStorage();
final auth = AuthCredentialsManager(storage: storage);
```

### 2. Register a User

The `registerUser` method handles validation and hashing automatically.

```dart
try {
  await auth.registerUser('user@example.com', 'securePassword123');
  print('User registered successfully.');
} on UserAlreadyExistsException {
  print('That userId is already in use.');
} on WeakPasswordException catch (e) {
  print('Password is too weak: ${e.message}');
}
```

### 3. Verify Credentials

```dart
try {
  await auth.verifyCredentials('user@example.com', 'securePassword123');
  print('Login successful!');
} on InvalidCredentialsException {
  print('Wrong password.');
} on UserDoesNotExistException {
  print('User not found.');
}
```

### 4. Update Password

```dart
await auth.updatePassword(
  'user@example.com',
  'securePassword123', // Old password
  'newPassword456',    // New password
);
```

## Examples

- **[Basic Usage Example](../../packages/portico_auth_credentials/example/main.dart):** Demonstrates registration, verification, and password updates in a single script.
