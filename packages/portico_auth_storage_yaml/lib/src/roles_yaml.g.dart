// GENERATED CODE - DO NOT MODIFY BY HAND

// coverage:ignore-file

part of 'roles_yaml.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RolesDoc _$RolesDocFromJson(Map<String, dynamic> json) => RolesDoc(
  kind: json['kind'] as String,
  roles:
      (json['roles'] as List<dynamic>?)
          ?.map((e) => Role.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  assignments:
      (json['assignments'] as List<dynamic>?)
          ?.map((e) => RoleAssignment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$RolesDocToJson(RolesDoc instance) => <String, dynamic>{
  'kind': instance.kind,
  'roles': instance.roles,
  'assignments': instance.assignments,
};
