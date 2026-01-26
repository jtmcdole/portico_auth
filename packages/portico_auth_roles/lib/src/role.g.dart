// GENERATED CODE - DO NOT MODIFY BY HAND

// coverage:ignore-file

part of 'role.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Role _$RoleFromJson(Map<String, dynamic> json) => Role(
  name: json['name'] as String,
  displayName: json['display_name'] as String? ?? '',
  description: json['description'] as String? ?? '',
  isActive: json['is_active'] as bool? ?? true,
);

Map<String, dynamic> _$RoleToJson(Role instance) => <String, dynamic>{
  'name': instance.name,
  'display_name': instance.displayName,
  'description': instance.description,
  'is_active': instance.isActive,
};
