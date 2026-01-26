# Portico Auth Roles

[![Portico Auth Roles](https://img.shields.io/badge/Portico_Auth-Roles-blue?style=for-the-badge&logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

<div style="text-align: center;">
<img src="../../assets/logo.svg" width="300" alt="Description of the image" />
</div>

A flexible Role-Based Access Control (RBAC) system for managing user permissions and assignments. This package provides a robust way to define roles and associate them with users, either globally or scoped to specific resources.

## Features

- **Role Definitions:** Create and manage roles with display names, descriptions, and activation states.
- **Scoped Assignments:** Assign roles to users globally or scoped to specific resources (e.g., `org:123`, `project:abc`).
- **Reactive Storage:** Compatible with multiple storage backends (SQLite, YAML, Memory) with automatic updates.
- **Role Lifecycle:** Deactivate roles to revoke access across all users without deleting assignment history.

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  portico_auth_roles: ^1.0.0
```

## Interactive Web Simulator

Experience the full capabilities of the Portico Auth ecosystem without setting up a backend. The **Web Simulator** runs the entire stack (Client, Server, and Storage) directly in your browser.

- **[Run the Web Simulator](https://jtmcdole.github.io/auth_simulator)**

## Usage

### 1. Initialize the Manager

```dart
import 'package:portico_auth_roles/portico_auth_roles.dart';

// Use InMemory storage for testing/prototyping
final storage = AuthRolesInMemoryStorage();
final manager = AuthRoleManager(storage);
```

### 2. Manage Roles

```dart
// Create a global 'admin' role
await manager.createRole(
  name: 'admin',
  displayName: 'Administrator',
  description: 'Full system access',
);

// Create a 'moderator' role
await manager.createRole(
  name: 'moderator',
  displayName: 'Moderator',
  description: 'Can moderate content',
);
```

### 3. Assign Roles (Global & Scoped)

```dart
const userId = 'user_123';

// Assign global admin role
await manager.assignRoleToUser(
  userId: userId,
  roleName: 'admin',
);

// Assign moderator role for a specific resource (Scoped)
await manager.assignRoleToUser(
  userId: userId,
  roleName: 'moderator',
  scope: 'resource_456',
);
```

### 4. Check Roles and Scopes

```dart
// Get all unique active role definitions assigned to the user
final roles = await manager.getUserRoles(userId);
print(roles.map((r) => r.name)); // ['admin', 'moderator']

// Get detailed assignments (including scopes)
final assignments = await manager.getUserAssignments(userId);
for (final assignment in assignments) {
  print('${assignment.roleName} (Scope: ${assignment.scope ?? "Global"})');
}
```

## Examples

- **[RBAC Core Verification](../../packages/portico_auth_roles/example/main.dart):** A script demonstrating the full lifecycle of roles and assignments.