/// Represents the structured payload of a validated token.
final class TokenRecord {
  /// The user's identifier (subject).
  final String userId;

  /// The user's name.
  final String name;

  /// The unique serial number for this token chain.
  final String serial;

  /// The full set of claims associated with the token.
  final Map<String, dynamic> claims;

  /// Creates a new [TokenRecord].
  TokenRecord({
    required this.userId,
    required this.name,
    required this.serial,
    required this.claims,
  });
}
