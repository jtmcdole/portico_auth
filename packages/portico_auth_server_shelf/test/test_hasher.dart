import 'package:cryptography/cryptography.dart' show Argon2id, SecretKeyData;
import 'package:portico_auth_credentials/portico_auth_credentials.dart'
    show HashAdapter;

final class ArgonTestHash implements HashAdapter {
  final Argon2id _argon2 = Argon2id(
    parallelism: 1,
    memory: 32,
    iterations: 1,
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
