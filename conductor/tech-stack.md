# Technology Stack

## Core Technologies
- **Language:** Dart (>=3.10.0)
- **Monorepo Management:** Melos and Pub Workspaces

## Backend & API
- **Web Framework:** Shelf (via `packages/portico_auth_server_shelf`) or Frog (via `packages/portico_auth_server_frog`)
- **Security & Tokens:** `jose_plus` (for JWT and JWE operations)
- **Logging:** `package:logging`
- **Validation:** `package:email_validator`
- **Credential Management:** `package:cryptography` (Argon2id)

## Data Storage
- **Primary Database:** SQLite
- **Database Drivers:** `sqlite3`, `sqflite_common_ffi`
- **Abstraction Layers:**
  - `portico_auth_storage_yaml` with `portico_auth_storage_yaml_io` for flat-file persistence (using `package:yaml`, `package:crypto`).
  - `portico_auth_storage_sqlite` for SQLite3 persistence (using `sqflite_common_ffi`).
  - `AuthTokensStorageAdapter` for token metadata.
  - `AuthCredentialsStorageAdapter` for user identities.

## Testing & Quality
- **Test Framework:** \`package:test\`, \`package:flutter_test\`
- **Linting:** Standard Dart linter
