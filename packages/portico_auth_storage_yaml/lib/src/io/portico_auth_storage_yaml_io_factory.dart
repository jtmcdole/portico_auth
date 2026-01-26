import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:portico_auth_storage_yaml/src/credentials_yaml.dart';
import 'package:portico_auth_storage_yaml/src/roles_yaml.dart';
import 'package:portico_auth_storage_yaml/src/tokens_yaml.dart';
import 'portico_auth_storage_yaml_io_handler.dart';

/// A factory for creating [AuthYamlIoHandler] instances.
///
/// This factory simplifies the creation of handlers for different YAML-based
/// storage types (tokens, roles, credentials) by managing a base directory
/// and providing sensible default filenames.
class AuthYamlIoFactory {
  /// The base directory where YAML files are stored.
  final Directory baseDir;

  /// Creates an [AuthYamlIoFactory] with the given [baseDir].
  AuthYamlIoFactory({required this.baseDir});

  /// Creates an [AuthYamlIoHandler] for [AuthTokensYaml].
  ///
  /// The [filename] defaults to 'tokens.yaml'.
  /// If [tokens] is provided, it will be used as the internal storage;
  /// otherwise, a new [AuthTokensYaml] instance is created.
  AuthYamlIoHandler<AuthTokensYaml> createTokensHandler({
    String filename = 'tokens.yaml',
    AuthTokensYaml? tokens,
  }) {
    final t = tokens ?? AuthTokensYaml();
    return AuthYamlIoHandler(
      t,
      File(p.join(baseDir.path, filename)),
      onExternalUpdate: t.update,
      setOnYamlUpdate: (cb) => t.onYamlUpdate = cb,
    );
  }

  /// Creates an [AuthYamlIoHandler] for [AuthRolesYaml].
  ///
  /// The [filename] defaults to 'roles.yaml'.
  /// If [roles] is provided, it will be used as the internal storage;
  /// otherwise, a new [AuthRolesYaml] instance is created.
  AuthYamlIoHandler<AuthRolesYaml> createRolesHandler({
    String filename = 'roles.yaml',
    AuthRolesYaml? roles,
  }) {
    final r = roles ?? AuthRolesYaml();
    return AuthYamlIoHandler(
      r,
      File(p.join(baseDir.path, filename)),
      onExternalUpdate: r.update,
      setOnYamlUpdate: (cb) => r.onYamlUpdate = cb,
    );
  }

  /// Creates an [AuthYamlIoHandler] for [AuthCredentialsYaml].
  ///
  /// The [filename] defaults to 'credentials.yaml'.
  /// If [credentials] is provided, it will be used as the internal storage;
  /// otherwise, a new [AuthCredentialsYaml] instance is created.
  AuthYamlIoHandler<AuthCredentialsYaml> createCredentialsHandler({
    String filename = 'credentials.yaml',
    AuthCredentialsYaml? credentials,
  }) {
    final c = credentials ?? AuthCredentialsYaml();
    return AuthYamlIoHandler(
      c,
      File(p.join(baseDir.path, filename)),
      onExternalUpdate: c.update,
      setOnYamlUpdate: (cb) => c.onYamlUpdate = cb,
    );
  }
}
