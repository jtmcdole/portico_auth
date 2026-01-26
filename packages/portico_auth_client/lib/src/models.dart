import 'package:meta/meta.dart';
import 'package:collection/collection.dart';

/// Represents the authentication state of the `AuthClient`.
sealed class AuthState {
  const AuthState();
}

/// The user is not authenticated.
final class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// The user is currently authenticating.
final class Authenticating extends AuthState {
  const Authenticating();
}

/// The user is successfully authenticated.
final class Authenticated extends AuthState {
  /// The currently authenticated user.
  final AuthUser user;

  const Authenticated(this.user);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Authenticated &&
          runtimeType == other.runtimeType &&
          user == other.user;

  @override
  int get hashCode => user.hashCode;
}

/// Represents a role assigned to a user, optionally scoped to a resource.
@immutable
final class UserRole {
  /// The name of the role (e.g., 'admin', 'editor').
  final String role;

  /// The scope of the role (e.g., 'org:123'), if applicable.
  final String? scope;

  const UserRole({required this.role, this.scope});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRole &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          scope == other.scope;

  @override
  int get hashCode => Object.hash(role, scope);

  @override
  String toString() => scope != null ? '$role:$scope' : role;
}

/// Represents an authenticated user with information extracted from the token.
@immutable
final class AuthUser {
  /// The user's unique identifier (usually email).
  final String id;

  /// The user's full name.
  final String? name;

  /// The roles assigned to the user.
  final List<UserRole> roles;

  const AuthUser({required this.id, this.name, required this.roles});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          const ListEquality().equals(roles, other.roles);
  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(roles));
}
