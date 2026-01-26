# Portico Auth Storage (SQLite)

[![Portico Auth Storage Sqlite](https://img.shields.io/badge/Portico_Auth-Storage_Sqlite-blue?style=for-the-badge&logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

<div style="text-align: center;">
<img src="../../assets/logo.svg" width="300" alt="Description of the image" />
</div>

SQLite persistence layer for Portico Auth credentials, roles, and tokens. This package provides a robust storage solution using SQLite, ensuring your authentication data is persisted reliably across server restarts.

## Features

- **Performant:** Uses `sqflite_common_ffi` for efficient and reliable database operations on desktop and server platforms.
- **Modular Adapters:** Separate adapters for managing `AuthCredentialsManager`, `AuthRoles`, and `AuthTokens` metadata.
- **Automatic Schema Management:** Handles table creation, indexes, and initialization automatically upon startup.
- **Thread-Safe:** Designed to handle concurrent access safely within a single process.

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  portico_auth_storage_sqlite: ^1.0.0
```

## Interactive Web Simulator

Experience the full capabilities of the Portico Auth ecosystem without setting up a backend. The **Web Simulator** runs the entire stack (Client, Server, and Storage) directly in your browser.

- **[Run the Web Simulator](https://jtmcdole.github.io/auth_simulator)**

## Usage

### 1. Initialize Database

> [!TIP]
> You can use an in-memory database for testing or a file-based database for production.

```dart
import 'package:portico_auth_storage_sqlite/portico_auth_storage_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  // Initialize FFI for desktop/server
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase('auth_service.db');

  // Initialize specific storage components
  final tokenStorage = AuthTokensSqlite(db);
  await tokenStorage.initialize();

  final credentialStorage = AuthCredentialsSqlite(db);
  await credentialStorage.initialize();

  final roleStorage = AuthRolesSqlite(db);
  await roleStorage.initialize();
}
```

### 2. Use with Portico Auth Managers

Pass the storage adapters to your managers.

```dart
final credentials = AuthCredentialsManager(storage: credentialStorage);
final roleManager = AuthRoleManager(roleStorage);
final tokenManager = AuthTokensManager(
  signingKey,
  encryptingKey,
  tokenStorage,
  // ...
);
```

## Examples

- **[SQLite Storage Lifecycle Example](../../packages/portico_auth_storage_sqlite/example/main.dart):** Demonstrates opening a database, initializing the schema, and performing basic CRUD operations for tokens.
