import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'role_assignment.g.dart';

/// Represents the assignment of a role to a specific user.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class RoleAssignment extends Equatable {
  /// The unique identifier of the user (usually an email).
  final String userId;

  /// The name of the role being assigned.
  final String roleName;

  /// The optional scope of the assignment (e.g., 'org:123').
  final String? scope;

  /// Creates a new [RoleAssignment].
  const RoleAssignment({
    required this.userId,
    required this.roleName,
    this.scope,
  });

  /// Creates a [RoleAssignment] from a JSON map.
  factory RoleAssignment.fromJson(Map<String, dynamic> json) =>
      _$RoleAssignmentFromJson(json);

  /// Converts this [RoleAssignment] to a JSON map.
  Map<String, dynamic> toJson() => _$RoleAssignmentToJson(this);

  @override
  List<Object?> get props => [userId, roleName, scope];
}
