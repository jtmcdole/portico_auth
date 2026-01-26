// GENERATED CODE - DO NOT MODIFY BY HAND

// coverage:ignore-file

part of 'credentials_yaml.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CredentialsDoc _$CredentialsDocFromJson(Map<String, dynamic> json) =>
    CredentialsDoc(
      kind: json['kind'] as String,
      credentials:
          (json['credentials'] as List<dynamic>?)
              ?.map((e) => UserCredential.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$CredentialsDocToJson(CredentialsDoc instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'credentials': instance.credentials,
    };

UserCredential _$UserCredentialFromJson(Map<String, dynamic> json) =>
    UserCredential(
      userId: json['user_id'] as String,
      salt: json['salt'] as String,
      hash: json['hash'] as String,
      creationTime: const DateConverter().fromJson(
        json['creation_time'] as String,
      ),
    );

Map<String, dynamic> _$UserCredentialToJson(UserCredential instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'salt': instance.salt,
      'hash': instance.hash,
      'creation_time': const DateConverter().toJson(instance.creationTime),
    };
