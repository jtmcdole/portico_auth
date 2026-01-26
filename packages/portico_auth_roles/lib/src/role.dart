import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'role.g.dart';

/// Represents a role definition in the system.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class Role extends Equatable {
  /// The unique programmatic name of the role (e.g., 'admin').
  final String name;

  /// A human-readable name for the role (e.g., 'Administrator').
  @JsonKey(defaultValue: '')
  final String displayName;

  /// A detailed description of what this role represents.
  @JsonKey(defaultValue: '')
  final String description;

  /// Whether this role is currently active.
  final bool isActive;

  /// Creates a new [Role].
  const Role({
    required this.name,
    required this.displayName,
    required this.description,
    this.isActive = true,
  });

  /// Creates a [Role] from a JSON map.
  factory Role.fromJson(Map<String, dynamic> json) => _$RoleFromJson(json);

  /// Converts this [Role] to a JSON map.
  Map<String, dynamic> toJson() => _$RoleToJson(this);

  @override
  List<Object?> get props => [name, displayName, description, isActive];
}
