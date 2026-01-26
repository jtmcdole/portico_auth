import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'token_storage.dart';

/// An in-memory implementation of token storage.
///
/// This storage is volatile and will be cleared when the application restarts.
final class InMemoryTokenStorage implements TokenStorage {
  TokenSet? _tokens;

  /// Saves the given [tokens] in memory.
  @override
  Future<void> save(TokenSet tokens) async {
    _tokens = tokens;
  }

  /// loads the tokens from memory.
  @override
  Future<TokenSet?> load() async {
    return _tokens;
  }

  /// Clears the tokens from memory.
  @override
  Future<void> clear() async {
    _tokens = null;
  }
}
