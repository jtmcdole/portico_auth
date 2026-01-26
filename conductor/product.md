# Initial Concept
The project currently implements a robust Token Management System with:
- JWT Access Tokens (Signed)
- JWE Refresh Tokens (Encrypted & Rotated)
- Replay attack detection
- SQLite storage for token metadata
- YAML-based storage with automatic file-system synchronization and reactive persistence
- Comprehensive Shelf integration for registration, login, and secure refreshing
- User credential management with hardened Argon2id hashing

# Product Guide

## Product Vision
A secure, modular, and stateless authentication service built for the Dart and Flutter ecosystem, providing a high-performance alternative to traditional authentication providers.

## Target Audience
- **Mobile Developers:** Needing a secure, lightweight backend for Flutter apps.
- **Web Developers:** Building Dart-based web applications.
- **Microservices:** Requiring reliable, stateless identity propagation across internal services.

## Key Goals
- **Stateless Security:** Use industry standards (JWT, JWE) to ensure security without requiring server-side session state.
- **Modular Architecture:** Maintain strict separation of concerns with swappable storage adapters (e.g., SQLite, PostgreSQL, Memory).
- **Extensible RBAC:** Provide a flexible Role-Based Access Control system that can be tailored to any application's needs.
- **Minimal Footprint:** Keep dependencies lean to ensure high performance and low maintenance.

## High-Level Features
- **Token Management:** Full lifecycle support for JWT Access and JWE Refresh tokens with rotation and replay detection.
- **Credential Management:** Secure user registration and authentication with hardened password hashing.
- **Multi-Factor Authentication (MFA):** Enhanced security layer for sensitive operations.
- **Administrative CLI:** A dedicated tool for managing users, roles, and server configuration.
- **Comprehensive SDKs:** Well-documented Dart/Flutter client libraries for rapid integration.
- **Interactive Simulator:** A full-stack web simulator for visualizing network traffic and authentication flows in real-time.
