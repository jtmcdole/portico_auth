import 'dart:async';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';

/// Interface for persisting and retrieving authentication tokens.
abstract interface class TokenStorage {
  /// Persists the given [tokensSet].
  FutureOr<void> save(TokenSet tokensSet);

  /// Retrieves the persisted tokens, or `null` if none exist.
  FutureOr<TokenSet?> load();

  /// Removes any persisted tokens.
  FutureOr<void> clear();
}
