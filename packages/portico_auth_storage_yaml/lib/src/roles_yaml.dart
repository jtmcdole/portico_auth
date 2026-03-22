import 'dart:collection';

import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'extensions.dart';

part 'roles_yaml.g.dart';

/// An adapter for [AuthRolesStorageAdapter] using a YAML backend.
class AuthRolesYaml implements AuthRolesStorageAdapter {
  /// Callback when the YAML content is updated.
  void Function(String yaml) onYamlUpdate = (_) {};

  final _roles = <String, Role>{};
  final _assignments = <String, RoleAssignment>{};

  /// Exposes roles for inspection.
  Map<String, Role> get roles => UnmodifiableMapView(_roles);

  /// Exposes assignments for inspection.
  List<RoleAssignment> get assignments =>
      UnmodifiableListView(_assignments.values);

  /// Creates a new [AuthRolesYaml].
  AuthRolesYaml({String? yaml}) {
    if (yaml != null) {
      update(yaml);
    }
  }

  /// Forcibly update the in memory storage based on external factors.
  void update(String yaml) {
    final docs = loadYamlDocuments(yaml);
    for (final doc in docs) {
      final contents = doc.contents;
      if (contents is YamlMap) {
        if (contents['kind'] == 'roles') {
          final rolesDoc = RolesDoc.fromJson(contents.asMap);
          for (final role in rolesDoc.roles) {
            _roles[role.name] = role;
          }
          for (final assignment in rolesDoc.assignments) {
            final key =
                '${assignment.userId}+${assignment.roleName}+${assignment.scope ?? ''}';
            _assignments[key] = assignment;
          }
          break;
        }
      }
    }
  }

  /// Creates a new role in YAML storage.
  ///
  /// Throws [RoleAlreadyExistsException] if a role with the same name exists.
  @override
  Future<void> createRole(Role role) async {
    if (_roles.containsKey(role.name)) {
      throw RoleAlreadyExistsException(role.name);
    }
    _roles[role.name] = role;
    _save();
  }

  /// Updates an existing role in YAML storage.
  ///
  /// Throws [RoleDoesNotExistException] if the role is not found.
  @override
  Future<void> updateRole(Role role) async {
    if (!_roles.containsKey(role.name)) {
      throw RoleDoesNotExistException(role.name);
    }
    _roles[role.name] = role;
    _save();
  }

  /// Retrieves a role by name from YAML storage.
  @override
  Future<Role?> getRole(String name) async {
    return _roles[name];
  }

  /// Lists all roles from YAML storage.
  @override
  Future<List<Role>> listRoles({bool includeInactive = false}) async {
    if (includeInactive) {
      return _roles.values.toList();
    }
    return _roles.values.where((r) => r.isActive).toList();
  }

  /// Assigns a role to a user in YAML storage.
  @override
  Future<void> assignRole({
    required String userId,
    required String roleName,
    String? scope,
  }) async {
    final key = '$userId+$roleName+${scope ?? ''}';
    _assignments[key] = RoleAssignment(
      userId: userId,
      roleName: roleName,
      scope: scope,
    );
    _save();
  }

  /// Unassigns a role from a user in YAML storage.
  @override
  Future<void> unassignRole({
    required String userId,
    required String roleName,
    String? scope,
  }) async {
    final key = '$userId+$roleName+${scope ?? ''}';
    _assignments.remove(key);
    _save();
  }

  /// Retrieves all active roles for a user from YAML storage.
  @override
  Future<List<Role>> getUserRoles(String userId) async {
    // Get all assignments for the user
    final userAssignments = await getUserAssignments(userId);
    final roleNames = userAssignments.map((a) => a.roleName).toSet();

    // Return active role definitions
    return _roles.values
        .where((r) => roleNames.contains(r.name) && r.isActive)
        .toList();
  }

  /// Retrieves all role assignments for a user from YAML storage.
  @override
  Future<List<RoleAssignment>> getUserAssignments(String userId) async {
    return _assignments.values.where((a) => a.userId == userId).toList();
  }

  void _save() {
    final rolesYaml = [for (final role in _roles.values) role.toJson()];
    final assignmentsYaml = [
      for (final assignment in _assignments.values) assignment.toJson(),
    ];

    final yaml = YamlEditor('')
      ..update([], {
        'kind': 'roles',
        'roles': rolesYaml,
        'assignments': assignmentsYaml,
      });
    onYamlUpdate('$yaml');
  }
}

/// Represents the top-level structure of a roles YAML document.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class RolesDoc {
  /// The document kind (should be 'roles').
  final String kind;

  /// The list of role definitions.
  @JsonKey(defaultValue: [])
  final List<Role> roles;

  /// The list of role assignments.
  @JsonKey(defaultValue: [])
  final List<RoleAssignment> assignments;

  /// Creates a new [RolesDoc].
  const RolesDoc({
    required this.kind,
    required this.roles,
    required this.assignments,
  });

  /// Creates a [RolesDoc] from a JSON map.
  factory RolesDoc.fromJson(Map<String, dynamic> json) =>
      _$RolesDocFromJson(json);

  /// Converts this [RolesDoc] to a JSON map.
  Map<String, dynamic> toJson() => _$RolesDocToJson(this);
}
