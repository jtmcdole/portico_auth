// GENERATED CODE - DO NOT MODIFY BY HAND

// coverage:ignore-file

part of 'tokens_yaml.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokensDoc _$TokensDocFromJson(Map<String, dynamic> json) => TokensDoc(
  kind: $enumDecode(_$YamlKindEnumMap, json['kind']),
  credentials:
      (json['credentials'] as List<dynamic>?)
          ?.map((e) => Credential.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$TokensDocToJson(TokensDoc instance) => <String, dynamic>{
  'kind': _$YamlKindEnumMap[instance.kind]!,
  'credentials': instance.credentials,
};

const _$YamlKindEnumMap = {
  YamlKind.roles: 'roles',
  YamlKind.credentials: 'credentials',
};

Credential _$CredentialFromJson(Map<String, dynamic> json) => Credential(
  serial: json['serial'] as String,
  userId: json['user_id'] as String,
  name: json['name'] as String,
  initialTime: const DateConverter().fromJson(json['initial_time'] as String),
  lastTime: const DateConverter().fromJson(json['last_time'] as String),
  counter: (json['counter'] as num).toInt(),
);

Map<String, dynamic> _$CredentialToJson(Credential instance) =>
    <String, dynamic>{
      'serial': instance.serial,
      'user_id': instance.userId,
      'name': instance.name,
      'initial_time': const DateConverter().toJson(instance.initialTime),
      'last_time': const DateConverter().toJson(instance.lastTime),
      'counter': instance.counter,
    };
