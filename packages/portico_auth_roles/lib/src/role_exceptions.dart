/// Base class for all role-related exceptions.
abstract class AuthRoleException implements Exception {
  final String message;
  AuthRoleException(this.message);

  @override
  String toString() => message;
}

class RoleAlreadyExistsException extends AuthRoleException {
  RoleAlreadyExistsException(String name) : super('Role already exists: $name');
}

class RoleDoesNotExistException extends AuthRoleException {
  RoleDoesNotExistException(String name) : super('Role does not exist: $name');
}
