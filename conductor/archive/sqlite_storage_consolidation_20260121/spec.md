# Specification: Consolidate SQLite Storage Packages

## Overview
This track involves refactoring the project's SQLite storage implementation by merging three separate packages—`portico_auth_roles_sqlite`, `portico_auth_credentials_sqlite`, and `portico_auth_tokens_sqlite`—into a single, unified package named `portico_auth_storage_sqlite`. This consolidation aims to simplify the monorepo structure, streamline dependency management, and improve maintainability.

## Goals
- Simplify dependency management within the monorepo by reducing the total number of packages.
- Consolidate all SQLite-specific persistence logic into a single cohesive library.
- Improve maintainability by centralizing shared SQLite utilities or boilerplate.

## Functional Requirements
- Create a new package `portico_auth_storage_sqlite` within the `packages/` directory.
- Port all logic, tests, and resources from the following packages into the new consolidated package:
    - `portico_auth_roles_sqlite`
    - `portico_auth_credentials_sqlite`
    - `portico_auth_tokens_sqlite`
- Organize the consolidated package to expose separate library exports for:
    - Roles storage
    - Credentials storage
    - Tokens storage
- Ensure all internal cross-references (e.g., between tokens and credentials if applicable at the SQLite level) are updated to local imports.

## Non-Functional Requirements
- Maintain existing test coverage for all storage implementations.
- Ensure the package adheres to the existing codebase's architectural patterns (adapters, models, etc.).

## Acceptance Criteria
- `portico_auth_storage_sqlite` is successfully created and functional.
- All tests for roles, credentials, and tokens pass within the new package.
- The three original packages are completely removed from the monorepo.
- All dependent packages (e.g., `web_simulator`, `portico_auth_server_shelf`) are updated to use the new `portico_auth_storage_sqlite` package.
- `dart analyze` passes across the entire workspace.

## Out of Scope
- Modifying the underlying schema or logic of the storage adapters themselves (unless required for consolidation).
- Adding new storage features.
