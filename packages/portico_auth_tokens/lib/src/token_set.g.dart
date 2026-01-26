// GENERATED CODE - DO NOT MODIFY BY HAND

// coverage:ignore-file

part of 'token_set.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokenSet _$TokenSetFromJson(Map<String, dynamic> json) => TokenSet(
  name: json['name'] as String,
  refreshToken: json['refresh_token'] as String,
  accessToken: json['access_token'] as String,
  expirationDate: const DateConverter().fromJson(
    json['expiration_date'] as String,
  ),
);

Map<String, dynamic> _$TokenSetToJson(TokenSet instance) => <String, dynamic>{
  'name': instance.name,
  'refresh_token': instance.refreshToken,
  'access_token': instance.accessToken,
  'expiration_date': const DateConverter().toJson(instance.expirationDate),
};
