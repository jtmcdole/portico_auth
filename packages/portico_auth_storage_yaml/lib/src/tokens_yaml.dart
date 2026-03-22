import 'dart:collection';

import 'package:portico_auth_tokens/portico_auth_tokens.dart'
    hide DateConverter;
import 'package:yaml/yaml.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'extensions.dart';

part 'tokens_yaml.g.dart';

/// An adapter for [AuthTokensStorageAdapter] using a YAML backend.
class AuthTokensYaml implements AuthTokensStorageAdapter {
  /// Callback when the YAML content is updated.
  void Function(String yaml) onYamlUpdate = (_) {};

  final _memory = <String, Credential>{};

  /// Exposes the internal memory for inspection.
  Map<String, Credential> get memory => UnmodifiableMapView(_memory);

  AuthTokensYaml({String? yaml}) {
    if (yaml != null) {
      update(yaml);
    }
  }

  /// Forcibly update the in memory storage based on external factors, example
  /// when files are updated by other processes.
  void update(String yaml) {
    final docs = loadYamlDocuments(yaml);
    for (final doc in docs) {
      final contents = doc.contents;
      if (contents is YamlMap) {
        if (contents['kind'] == 'credentials') {
          final tokensDoc = TokensDoc.fromJson(contents.asMap);
          for (final cred in tokensDoc.credentials) {
            _memory['${cred.serial}+${cred.userId}'] = cred;
          }
          break;
        }
      }
    }
  }

  /// Deletes the refresh token for the given [serial] and [userId] so that
  /// it cannot be used again for authentication.
  @override
  Future<void> invalidateRefreshToken({
    required String serial,
    required String userId,
  }) async {
    final found = _memory.remove('$serial+$userId');
    if (found == null) return;
    _save();
  }

  /// Record a new refresh token for authenticating the [userId].
  @override
  Future<void> recordRefreshToken({
    required String serial,
    required String userId,
    required DateTime initial,
    required DateTime lastUpdate,
    required num counter,
    required String name,
  }) async {
    _memory['$serial+$userId'] = Credential(
      serial: serial,
      userId: userId,
      name: name,
      initialTime: initial,
      lastTime: lastUpdate,
      counter: counter.toInt(),
    );
    _save();
  }

  /// Get the refresh counters for the [serial] and [userId], of which there
  /// should be either 1 or none.
  @override
  Future<List<num>> getRefreshTokenCounter({
    required String serial,
    required String userId,
  }) async {
    return [?_memory['$serial+$userId']?.counter];
  }

  /// Record the new counter for [serial] and [userId].
  @override
  Future<void> updateRefreshTokenCounter({
    required String serial,
    required String userId,
    required DateTime lastUpdate,
    required num counter,
  }) async {
    final record = _memory['$serial+$userId'];
    if (record == null) throw 'missing record';
    _memory['$serial+$userId'] = Credential(
      serial: serial,
      userId: userId,
      name: record.name,
      initialTime: record.initialTime,
      lastTime: lastUpdate,
      counter: counter.toInt(),
    );
    _save();
  }

  void _save() {
    final credentials = [for (final cred in _memory.values) cred.toJson()];

    final yaml = YamlEditor('')
      ..update([], {
        'kind': YamlKind.credentials.name,
        'credentials': credentials,
      });

    onYamlUpdate('$yaml');
  }
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class TokensDoc {
  final YamlKind kind;

  @JsonKey(defaultValue: [])
  final List<Credential> credentials;

  const TokensDoc({required this.kind, required this.credentials});

  factory TokensDoc.fromJson(Map<String, dynamic> json) =>
      _$TokensDocFromJson(json);

  Map<String, dynamic> toJson() => _$TokensDocToJson(this);
}

enum YamlKind { roles, credentials }

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class Credential {
  final String serial;
  final String userId;
  final String name;

  @DateConverter()
  final DateTime initialTime;

  @DateConverter()
  final DateTime lastTime;
  final int counter;

  const Credential({
    required this.serial,
    required this.userId,
    required this.name,
    required this.initialTime,
    required this.lastTime,
    required this.counter,
  });

  factory Credential.fromJson(Map<String, dynamic> json) =>
      _$CredentialFromJson(json);

  Map<String, dynamic> toJson() => _$CredentialToJson(this);
}
