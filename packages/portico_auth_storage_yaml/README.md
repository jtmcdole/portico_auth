# Portico Auth Storage (YAML)

[![Portico Auth Storage Yaml](https://img.shields.io/badge/Portico_Auth-Storage_Yaml-blue?style=for-the-badge&logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

<div style="text-align: center;">
<img src="../../assets/logo.svg" width="300" alt="Description of the image" />
</div>

A file-based YAML storage backend with automatic synchronization and reactive persistence. This package is ideal for small projects, prototyping, or scenarios where human-readable configuration files are preferred.

## Features

- **Human Readable:** Store your authentication data in simple, structured YAML files that can be easily inspected or edited.
- **Hot Reloading:** Automatically detects and reacts to manual file changes on disk, updating the internal state in real-time.
- **Atomic Writes:** Ensures data integrity by using a "write-then-move" strategy with temporary files, preventing data loss during crashes.
- **Reactive Stream:** Built-in support for listening to storage changes.

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  portico_auth_storage_yaml: ^1.0.0
```

## Interactive Web Simulator

Experience the full capabilities of the Portico Auth ecosystem without setting up a backend. The **Web Simulator** runs the entire stack (Client, Server, and Storage) directly in your browser.

- **[Run the Web Simulator](https://jtmcdole.github.io/auth_simulator)**

## Usage

### 1. Initialize the YAML Factory

The `YamlStorageFactory` handles the file I/O and synchronization logic.

```dart
import 'dart:io';
import 'package:portico_auth_storage_yaml/portico_auth_storage_yaml_io.dart';

void main() async {
  final directory = Directory('./auth_data');
  if (!await directory.exists()) await directory.create();

  // Initialize the factory with a directory
  final factory = YamlStorageFactory(directory);

  // Create adapters for specific components
  final credentialStorage = factory.createCredentialsStorage('users.yaml');
  final roleStorage = factory.createRolesStorage('roles.yaml');
  final tokenStorage = factory.createTokensStorage('tokens.yaml');
}
```

### 2. Use with Portico Auth Managers

Pass the storage adapters to your managers just like any other storage backend.

```dart
final credentials = AuthCredentialsManager(storage: credentialStorage);
final roleManager = AuthRoleManager(roleStorage);
```

### 3. Reactive Updates

The YAML storage will automatically reload if you edit the files manually on disk (e.g., via a text editor).

```dart
credentialStorage.onChanged.listen((data) {
  print('Credentials file was updated on disk!');
});
```

## Examples

- **[Atomic File Writer Example](../../packages/portico_auth_storage_yaml/example/main.dart):** A low-level example demonstrating the internal atomic writing mechanism.
