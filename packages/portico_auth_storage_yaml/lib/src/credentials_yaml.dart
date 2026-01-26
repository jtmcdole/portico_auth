import 'dart:collection';

import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

import 'extensions.dart';

part 'credentials_yaml.g.dart';

/// An adapter for [AuthCredentialsStorageAdapter] using a YAML backend.
class AuthCredentialsYaml implements AuthCredentialsStorageAdapter {
  /// Callback when the YAML content is updated.
  void Function(String yaml) onYamlUpdate = (_) {};

  final _credentials = <String, UserCredential>{};

  /// Exposes credentials for inspection.
  Map<String, UserCredential> get credentials =>
      UnmodifiableMapView(_credentials);

  /// Creates a new [AuthCredentialsYaml].
  AuthCredentialsYaml({String? yaml}) {
    if (yaml != null) {
      update(yaml);
    }
  }

  /// Forcibly update the in memory storage based on external factors.
  void update(String yaml) {
    final docs = loadYamlDocuments(yaml);
    for (final doc in docs) {
      final contents = doc.contents;
      if (contents is YamlMap) {
        if (contents['kind'] == 'user_credentials') {
          final credentialsDoc = CredentialsDoc.fromJson(contents.asMap);
          _credentials.clear();
          for (final cred in credentialsDoc.credentials) {
            _credentials[cred.userId] = cred;
          }
          break;
        }
      }
    }
  }

  /// Creates a new user in YAML storage.
  ///
  /// Throws [UserAlreadyExistsException] if the user already exists.
  @override
  Future<void> createUser({
    required String userId,
    required String salt,
    required String hash,
    required DateTime creationTime,
  }) async {
    if (_credentials.containsKey(userId)) {
      throw UserAlreadyExistsException(userId);
    }
    _credentials[userId] = UserCredential(
      userId: userId,
      salt: salt,
      hash: hash,
      creationTime: creationTime,
    );
    _save();
  }

  /// Updates the password for a user in YAML storage.
  ///
  /// Throws [UserDoesNotExistException] if the user is not found.
  @override
  Future<void> updatePassword({
    required String userId,
    required String salt,
    required String hash,
  }) async {
    final existing = _credentials[userId];
    if (existing == null) {
      throw UserDoesNotExistException(userId);
    }
    _credentials[userId] = UserCredential(
      userId: userId,
      salt: salt,
      hash: hash,
      creationTime: existing.creationTime,
    );
    _save();
  }

  /// Retrieves the password hash and salt for a user from YAML storage.
  @override
  Future<CredentialHash> getPasswordHash(String userId) async {
    final cred = _credentials[userId];
    if (cred == null) {
      throw UserDoesNotExistException(userId);
    }
    return (hash: cred.hash, salt: cred.salt);
  }

  /// Deletes a user from YAML storage.
  @override
  Future<void> deleteUser(String userId) async {
    if (!_credentials.containsKey(userId)) {
      throw UserDoesNotExistException(userId);
    }
    _credentials.remove(userId);
    _save();
  }

  void _save() {
    final credsYaml = [
      for (var cred in _credentials.values)
        [
          for (final MapEntry(:key, :value) in cred.toJson().entries)
            '$key: $value',
        ].join('\n    '),
    ];

    onYamlUpdate('''
kind: user_credentials
credentials:
${[for (final c in credsYaml) '  - $c'].join('\n')}
''');
  }
}

/// Represents the top-level structure of a credentials YAML document.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class CredentialsDoc {
  /// The document kind (should be 'user_credentials').
  final String kind;

  /// The list of user credentials.
  @JsonKey(defaultValue: [])
  final List<UserCredential> credentials;

  /// Creates a new [CredentialsDoc].
  const CredentialsDoc({required this.kind, required this.credentials});

  /// Creates a [CredentialsDoc] from a JSON map.
  factory CredentialsDoc.fromJson(Map<String, dynamic> json) =>
      _$CredentialsDocFromJson(json);

  /// Converts this [CredentialsDoc] to a JSON map.
  Map<String, dynamic> toJson() => _$CredentialsDocToJson(this);
}

/// Represents a single user's credential information in YAML.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class UserCredential {
  /// The user's unique identifier (e.g. email).
  final String userId;

  /// The user's salt (base64 encoded).
  final String salt;

  /// The user's password hash (base64 encoded).
  final String hash;

  /// When the user was created.
  @DateConverter()
  final DateTime creationTime;

  /// Creates a new [UserCredential].
  const UserCredential({
    required this.userId,
    required this.salt,
    required this.hash,
    required this.creationTime,
  });

  /// Creates a [UserCredential] from a JSON map.
  factory UserCredential.fromJson(Map<String, dynamic> json) =>
      _$UserCredentialFromJson(json);

  /// Converts this [UserCredential] to a JSON map.
  Map<String, dynamic> toJson() => _$UserCredentialToJson(this);
}
