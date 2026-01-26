// GENERATED CODE - DO NOT MODIFY BY HAND

// coverage:ignore-file

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  roles:
      (json['roles'] as List<dynamic>?)
          ?.map((e) => UserRole.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'roles': instance.roles.map((e) => e.toJson()).toList(),
  'metadata': instance.metadata,
};
