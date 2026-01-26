import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'token_set.g.dart';

/// Converts between [DateTime] and ISO-8601 strings.
class DateConverter implements JsonConverter<DateTime, String> {
  /// Creates a new [DateConverter].
  const DateConverter();

  @override
  DateTime fromJson(String timestamp) {
    return DateTime.parse(timestamp);
  }

  @override
  String toJson(DateTime date) => date.toIso8601String();
}

/// A set of tokens returned after successful authentication.
@JsonSerializable(fieldRename: FieldRename.snake)
class TokenSet extends Equatable {
  /// The Token's name.
  final String name;

  /// The encrypted refresh token (JWE).
  final String refreshToken;

  /// The signed access token (JWT).
  final String accessToken;

  /// When the access token expires.
  @DateConverter()
  final DateTime expirationDate;

  /// Creates a new [TokenSet].
  const TokenSet({
    required this.name,
    required this.refreshToken,
    required this.accessToken,
    required this.expirationDate,
  });

  /// Creates a [TokenSet] from a JSON map.
  factory TokenSet.fromJson(Map<String, dynamic> json) =>
      _$TokenSetFromJson(json);

  /// Converts this [TokenSet] to a JSON map.
  Map<String, dynamic> toJson() => _$TokenSetToJson(this);

  @override
  List<Object?> get props => [name, refreshToken, accessToken, expirationDate];
}
