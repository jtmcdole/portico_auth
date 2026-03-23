import 'dart:convert';
import 'package:portico_auth_credentials/src/hash_adapter.dart';
import 'package:clock/clock.dart';
import 'credentials_storage_adapter.dart';
import 'credential_exceptions.dart';

/// Provides validation logic for user identifiers and passwords.
final class AuthValidation {
  /// Validates the user identifier (e.g., email or username).
  final bool Function(String user) user;

  /// Validates a username (length > 3).
  static bool validateUsername(String username) {
    if (username.trim().length < 3) {
      throw InvalidCredentialsException('invalid username');
    }
    return true;
  }

  /// Validates a password.
  final bool Function(String password) password;

  /// Regular expression for special characters.
  static final specialsRegex = RegExp(
    r'''[!@#$%^&*()_+[\]{};':",./<>?\\|`~=-]''',
  );

  /// Regular expression for digits.
  static final digitsRegex = RegExp(r'\d');

  /// Regular expression for capital letters.
  static final capitalRegex = RegExp(r'[A-Z]');

  /// Regular expression for lowercase letters.
  static final lowerRegex = RegExp(r'[a-z]');

  /// Validates that a password is at least 8 characters long.
  ///
  /// Throws [InvalidCredentialsException] if the password is too short.
  static bool validatePasswordLength(String password) {
    if (password.length < 8) {
      throw InvalidCredentialsException('Password too short');
    }
    return true;
  }

  /// Validates that a password is at least 8 characters long and contains
  /// at least one special character, digit, capital letter, and lowercase letter.
  ///
  /// Throws [InvalidCredentialsException] if any criteria are not met.
  static bool validatePasswordRigid(String password) {
    if (password.length < 8 ||
        !password.contains(specialsRegex) ||
        !password.contains(digitsRegex) ||
        !password.contains(capitalRegex) ||
        !password.contains(lowerRegex)) {
      throw InvalidCredentialsException('Password not complex enough');
    }
    return true;
  }

  /// Creates a standard validation with user validation and minimum length check.
  const AuthValidation({
    this.user = validateUsername,
    this.password = validatePasswordLength,
  });

  /// Creates a rigid validation with user validation and strong password requirements.
  const AuthValidation.rigid()
    : user = validateUsername,
      password = validatePasswordRigid;
}

/// Core service for managing user credentials.
class AuthCredentialsManager {
  final AuthCredentialsStorageAdapter storage;
  final AuthValidation validator;

  /// Password hashing methods
  final HashAdapter hasher;

  AuthCredentialsManager({
    required this.storage,
    this.validator = const AuthValidation(),
    HashAdapter? hasher,
  }) : hasher = hasher ?? Argon2IdHash();

  /// Registers a new user with the given [userId] and [password].
  Future<void> registerUser(String userId, String password) async {
    validator.password(password);
    validator.user(userId);

    final salt = await hasher.salt();
    final hash = await hasher.hash(password, salt);

    await storage.createUser(
      userId: userId,
      salt: base64.encode(salt),
      hash: base64.encode(hash),
      creationTime: clock.now(),
    );
  }

  /// Verifies if the given [password] is correct for the user with [userId].
  ///
  /// Throws [UserDoesNotExistException] if the user does not exist.
  /// Throws [InvalidCredentialsException] if [password] is incorrect.
  Future<bool> verifyCredentials(String userId, String password) async {
    final credentials = await storage.getPasswordHash(userId);

    final saltBytes = base64.decode(credentials.salt);
    final expectedHashBytes = base64.decode(credentials.hash);

    final hashBytes = await hasher.hash(password, saltBytes);

    // Constant-time comparison
    var result = 0;
    if (hashBytes.length != expectedHashBytes.length) {
      result = 1;
    } else {
      for (var i = 0; i < hashBytes.length; i++) {
        result |= hashBytes[i] ^ expectedHashBytes[i];
      }
    }

    if (result != 0) throw const InvalidCredentialsException();

    return true;
  }

  /// Updates the password for the user with [userId].
  ///
  /// Verifies [oldPassword] first. If valid, generates a new salt and hash for
  /// [newPassword] and updates the storage.
  ///
  /// Throws [UserDoesNotExistException] if the user does not exist.
  /// Throws [InvalidCredentialsException] if [oldPassword] is incorrect.
  Future<void> updatePassword(
    String userId,
    String oldPassword,
    String newPassword,
  ) async {
    await verifyCredentials(userId, oldPassword);
    validator.password(newPassword);

    final salt = await hasher.salt();
    final hash = await hasher.hash(newPassword, salt);

    await storage.updatePassword(
      userId: userId,
      salt: base64.encode(salt),
      hash: base64.encode(hash),
    );
  }

  /// Deletes the user with the given [userId].
  Future<void> deleteUser(String userId) async {
    await storage.deleteUser(userId);
  }
}
