import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'user_role.dart';

part 'user.g.dart';

@JsonSerializable(explicitToJson: true)
class User extends Equatable {
  const User({
    required this.id,
    this.roles = const [],
    this.metadata = const {},
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  final String id;
  final List<UserRole> roles;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [id, roles, metadata];
}
