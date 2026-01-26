// GENERATED CODE - DO NOT MODIFY BY HAND

// coverage:ignore-file

part of 'user_role.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserRole _$UserRoleFromJson(Map<String, dynamic> json) => UserRole(
  role: json['role'] as String,
  scope: json['scope'] as String? ?? '',
);

Map<String, dynamic> _$UserRoleToJson(UserRole instance) => <String, dynamic>{
  'role': instance.role,
  'scope': instance.scope,
};
