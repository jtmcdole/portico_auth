import 'package:cryptography/cryptography.dart' show Argon2id, SecretKeyData;

/// Interface for password hashing and salt generation.
abstract interface class HashAdapter {
  /// Generates a new random salt.
  Future<List<int>> salt();

  /// Hashes a [password] with the given [salt].
  Future<List<int>> hash(String password, List<int> salt);
}

/// An Argon2id implementation of password hashing.
final class Argon2IdHash implements HashAdapter {
  final Argon2id _argon2 = Argon2id(
    parallelism: 4,
    memory: 32 * 1024, // 32 MiB
    iterations: 3,
    hashLength: 32,
  );

  /// Generates a 16-byte random salt.
  @override
  Future<List<int>> salt() async => SecretKeyData.random(length: 16).bytes;

  /// Hashes a [password] using Argon2id with the given [salt].
  @override
  Future<List<int>> hash(String password, List<int> salt) async =>
      (await _argon2.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      )).extractBytes();
}
