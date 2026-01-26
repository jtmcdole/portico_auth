# Portico Auth Client

[![Portico Auth Client](https://img.shields.io/badge/Portico_Auth-Client-blue?style=for-the-badge&logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

<div style="text-align: center;">
<img src="../../assets/logo.svg" width="300" alt="Description of the image" />
</div>

A Dart-native SDK for user authentication and token management. This package provides a high-level client for interacting with Portico Auth servers, handling token storage, automatic refreshing, and state management.

## Features

- **Automated Refresh:** Automatically handles access token expiration and refresh logic with jitter.
- **Pluggable Storage:** Support for in-memory and custom storage adapters.
- **State Management:** Easy integration with UI frameworks via `onAuthStateChanged` callbacks and reactive state patterns.
- **Type-Safe Models:** Built-in models for Users, Roles, and Authentication States using Dart's powerful pattern matching.

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  portico_auth_client: ^1.0.0
```

## Interactive Web Simulator

Experience the full capabilities of the Portico Auth ecosystem without setting up a backend. The **Web Simulator** runs the entire stack (Client, Server, and Storage) directly in your browser.

- **[Run the Web Simulator](https://jtmcdole.github.io/auth_simulator)**
- **Explore the Source:** [examples/web_simulator](../../examples/web_simulator)

## Usage

### Initialization

```dart
import 'package:portico_auth_client/portico_auth_client.dart';

final client = AuthClient(
  baseUrl: Uri.parse('https://api.example.com'),
);

// Wait for initialization (loads tokens from storage)
await client.ready;
```

### Registration & Login

```dart
// Register a new user
await client.register('user@example.com', 'password123');

// Login
await client.login('user@example.com', 'password123');
```

### Reactive State Management

Use Dart's pattern matching to handle different authentication states gracefully:

```dart
void checkAuth() {
  switch (client.state) {
    case Authenticated(:final user):
      print('Welcome back, ${user.id}!');
      print('Roles: ${user.roles}');
    case Authenticating():
      print('Please wait...');
    case Unauthenticated():
      print('Please log in.');
  }
}

// Or listen to changes
client.onAuthStateChanged = (state) => checkAuth();
```

### Making Authenticated Requests

Use `httpHeaders()` to automatically manage your `Authorization` header. This method handles token refresh behind the scenes, ensuring your requests never fail due to expiration.

```dart
final headers = await client.httpHeaders();
final response = await http.get(
  Uri.parse('https://api.example.com/protected-resource'),
  headers: headers,
);
```

### Logout

```dart
await client.logout();
```

## Examples

- **[Basic Example](../../packages/portico_auth_client/example/main.dart):** A simple script demonstrating registration, login, and logout.
- **[Interactive CLI](../../packages/portico_auth_client/example/interactive_cli.dart):** A command-line tool to test auth flows manually.
- **[Web Simulator](../../examples/web_simulator):** A full Flutter web application simulating the entire auth ecosystem.