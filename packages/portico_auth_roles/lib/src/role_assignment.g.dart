// GENERATED CODE - DO NOT MODIFY BY HAND

// coverage:ignore-file

part of 'role_assignment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoleAssignment _$RoleAssignmentFromJson(Map<String, dynamic> json) =>
    RoleAssignment(
      userId: json['user_id'] as String,
      roleName: json['role_name'] as String,
      scope: json['scope'] as String?,
    );

Map<String, dynamic> _$RoleAssignmentToJson(RoleAssignment instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'role_name': instance.roleName,
      'scope': ?instance.scope,
    };
