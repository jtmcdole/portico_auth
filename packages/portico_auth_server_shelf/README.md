# Portico Auth Server (Shelf)

[![Portico Auth Server Shelf](https://img.shields.io/badge/Portico_Auth-Server_Shelf-blue?style=for-the-badge&logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

<div style="text-align: center;">
<img src="../../assets/logo.svg" width="300" alt="Description of the image" />
</div>

Shelf-based handlers and middleware for building secure authentication servers in Dart. This package simplifies the integration of the Portico Auth ecosystem into your existing Shelf-based backend.

## Features

- **Standard Handlers:** Ready-to-use handlers for login, registration, logout, and token refresh.
- **Stateless Authorization:** Middleware that can automatically validates JWT Access Tokens and populates the request context.
- **Granular RBAC:** Helpers for enforcing Role-Based Access Control, including support for scoped permissions.
- **Exception Mapping:** Automatically translates authentication and authorization errors into appropriate HTTP responses (401, 403, etc.).

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  portico_auth_server_shelf: ^1.0.0
```

## Interactive Web Simulator

Experience the full capabilities of the Portico Auth ecosystem without setting up a backend. The **Web Simulator** runs the entire stack (Client, Server, and Storage) directly in your browser.

- **[Run the Web Simulator](https://jtmcdole.github.io/auth_simulator)**

## Usage

### 1. Initialization

Combine the various Portico Auth components into a single `AuthShelf` instance.

```dart
import 'package:portico_auth_server_shelf/portico_auth_server_shelf.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:portico_auth_credentials/portico_auth_credentials.dart';

final authServer = AuthShelf(
  tokenManager, // from portico_auth_tokens
  credentials: credentials, // from portico_auth_credentials
  roleManager: roleManager, // from portico_auth_roles
);
```

### 2. Configure the Pipeline

Use the provided middleware to secure your routes. The `exceptionRequestHandler` should be placed early in the pipeline to catch authorization errors.

```dart
final handler = Pipeline()
    .addMiddleware(authServer.exceptionRequestHandler) // Map errors to 401/403
    .addMiddleware(authServer.middleware)        // Validate JWTs
    .addHandler(router.call);
```

### 3. Register Authentication Endpoints

Mount the standard handlers for common authentication tasks.

```dart
final router = Router();

router.post('/register', authServer.register);
router.post('/login', authServer.login);
router.post('/logout', authServer.logout);
router.post('/refresh', authServer.refresh);
```

### 4. Protect Routes with RBAC

Enforce roles directly within your handlers. This supports both global roles and those scoped to specific resources (like a project ID from the path).

```dart
router.get('/projects/<id>/settings', (Request request, String id) {
  // Throws ForbiddenException if the user lacks the 'admin' role for this 'id'
  authServer.requiredRole(request, 'admin', scope: id);

  return Response.ok('Settings for project $id');
});
```

## Examples

- **[Full Shelf Server Example](../../packages/portico_auth_server_shelf/example/main.dart):** A complete, runnable server demonstrating registration, login, protected routes, and RBAC.
