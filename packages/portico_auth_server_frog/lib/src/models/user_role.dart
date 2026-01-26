import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_role.g.dart';

@JsonSerializable()
class UserRole extends Equatable {
  const UserRole({required this.role, this.scope = ''});

  factory UserRole.fromJson(Map<String, dynamic> json) =>
      _$UserRoleFromJson(json);

  final String role;

  @JsonKey(defaultValue: '')
  final String scope;

  Map<String, dynamic> toJson() => _$UserRoleToJson(this);

  @override
  List<Object?> get props => [role, scope];
}
