# Implementation Plan - Consolidate SQLite Packages

## Phase 1: Setup and Scaffolding [checkpoint: 7b468ea]
- [x] Task: Create new package `portico_auth_storage_sqlite`
    - [x] Run `create_project` tool to scaffold the package.
    - [x] Update `pubspec.yaml` with necessary dependencies (`sqflite_common_ffi`, `sqlite3`, `path`, etc.) from the old packages.
    - [x] Conductor - User Manual Verification 'Setup and Scaffolding' (Protocol in workflow.md)

## Phase 2: Migration [checkpoint: ef95334]
- [x] Task: Port Credentials Implementation 7bdf844
    - [x] Move source files from `portico_auth_credentials_sqlite/lib` to `portico_auth_storage_sqlite/lib`.
    - [x] Move tests from `portico_auth_credentials_sqlite/test` to `portico_auth_storage_sqlite/test`.
    - [x] Refactor imports to match the new package structure.
- [x] Task: Port Roles Implementation c0193f7
    - [x] Move source files from `portico_auth_roles_sqlite/lib` to `portico_auth_storage_sqlite/lib`.
    - [x] Move tests from `portico_auth_roles_sqlite/test` to `portico_auth_storage_sqlite/test`.
    - [x] Refactor imports to match the new package structure.
- [x] Task: Port Tokens Implementation 93676a7
    - [x] Move source files from `portico_auth_tokens_sqlite/lib` to `portico_auth_storage_sqlite/lib`.
    - [x] Move tests from `portico_auth_tokens_sqlite/test` to `portico_auth_storage_sqlite/test`.
    - [x] Refactor imports to match the new package structure.
- [x] Task: Verify Tests
    - [x] Run `dart test` in the new package to ensure all migrations were successful.
    - [x] Conductor - User Manual Verification 'Migration' (Protocol in workflow.md)

## Phase 3: Cleanup and Integration [checkpoint: e340fe3]
- [x] Task: Update Dependencies
    - [x] Update `pubspec.yaml` in the root and all consuming packages (e.g., `web_simulator`, `portico_auth_server_*`) to depend on `portico_auth_storage_sqlite`.
    - [x] Update code imports in consuming packages to point to the new library exports.
- [x] Task: Remove Old Packages 0197ab6
    - [x] Delete `portico_auth_credentials_sqlite` directory.
    - [x] Delete `portico_auth_roles_sqlite` directory.
    - [x] Delete `portico_auth_tokens_sqlite` directory.
    - [x] Remove deleted packages from the root `pubspec.yaml` workspace list.
- [x] Task: Final Verification
    - [x] Run `melos bootstrap`.
    - [x] Run `dart analyze .`.
    - [x] Run all tests across the workspace to ensure no regressions.
    - [x] Conductor - User Manual Verification 'Cleanup and Integration' (Protocol in workflow.md)
