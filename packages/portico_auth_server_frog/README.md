# Portico Auth Server (Frog)

[![Portico Auth Server Frog](https://img.shields.io/badge/Portico_Auth-Server_Frog-blue?style=for-the-badge&logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

<div style="text-align: center;">
<img src="../../assets/logo.svg" width="300" alt="Description of the image" />
</div>

A set of Dart Frog handlers and middleware for building secure authentication servers. This package provides a seamless way to integrate the Portico Auth ecosystem into your Dart Frog application, leveraging its provider-based dependency injection.

## Features

- **Integrated Auth:** Built-in support for `AuthTokensManager`, `AuthCredentialsManager`, and `AuthRoleManager`.
- **Dependency Injection:** Designed to work naturally with Dart Frog's `RequestContext` and providers.
- **Typed Users:** Automatically validates JWT Access Tokens and injects the authenticated user's information into the context.
- **Web-Ready:** Comprehensive handlers for registration, login, logout, and token refreshing.

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  portico_auth_server_frog: ^1.0.0
```

## Interactive Web Simulator

Experience the full capabilities of the Portico Auth ecosystem without setting up a backend. The **Web Simulator** runs the entire stack (Client, Server, and Storage) directly in your browser.

- **[Run the Web Simulator](https://jtmcdole.github.io/auth_simulator)**

## Usage

### 1. Initialize AuthFrog

Typically, you would initialize `AuthFrog` in a top-level middleware or global configuration.

```dart
import 'package:portico_auth_server_frog/portico_auth_server_frog.dart';

final authFrog = AuthFrog(
  tokens: tokenManager, // from portico_auth_tokens
  credentials: credentials, // from portico_auth_credentials
  roles: roleManager, // (optional) from portico_auth_roles
);
```

### 2. Configure Middleware

Secure your routes by adding the `authCheck` middleware. This ensures that only requests with a valid JWT can proceed to the handler.

```dart
// middleware.dart
Handler middleware(Handler handler) {
  return handler.use(authFrog.authCheck());
}
```

### 3. Use Handlers in Routes

Mount the provided handlers to your application's routes.

```dart
// routes/login.dart
Future<Response> onRequest(RequestContext context) {
  return authFrog.login(context);
}

// routes/register.dart
Future<Response> onRequest(RequestContext context) {
  return authFrog.register(context);
}
```

### 4. Access Authenticated User Data

Once authenticated, you can access the user's claims and roles directly from the request context.

```dart
// routes/protected.dart
Response onRequest(RequestContext context) {
  final user = context.read<AuthUser>();
  return Response(body: 'Hello, ${user.id}!');
}
```

## Examples

- **[AuthFrog Configuration Example](../../packages/portico_auth_server_frog/example/main.dart):** Demonstrates how to initialize and configure AuthFrog with its dependencies.
