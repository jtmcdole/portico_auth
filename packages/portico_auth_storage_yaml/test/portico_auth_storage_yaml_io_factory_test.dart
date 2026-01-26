import 'dart:io';
import 'package:test/test.dart';
import 'package:portico_auth_storage_yaml/portico_auth_storage_yaml_io.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hermetic_factory_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('AuthYamlIoFactory creates handlers with correct paths', () async {
    final factory = AuthYamlIoFactory(baseDir: tempDir);

    final tokensHandler = factory.createTokensHandler(
      filename: 'my_tokens.yaml',
    );
    await tokensHandler.start();

    // Verify file creation on write
    await tokensHandler.internal.recordRefreshToken(
      serial: '123',
      userId: 'u',
      initial: DateTime.now(),
      lastUpdate: DateTime.now(),
      counter: 1,
      name: 't',
    );
    await Future.delayed(Duration(milliseconds: 200));

    final file = File('${tempDir.path}/my_tokens.yaml');
    expect(await file.exists(), isTrue);

    await tokensHandler.stop();
  });

  test('AuthYamlIoFactory uses provided instances', () async {
    final factory = AuthYamlIoFactory(baseDir: tempDir);
    final tokens = AuthTokensYaml();

    final tokensHandler = factory.createTokensHandler(tokens: tokens);
    expect(tokensHandler.internal, same(tokens));
  });

  test('AuthYamlIoFactory creates roles and credentials handlers', () async {
    final factory = AuthYamlIoFactory(baseDir: tempDir);

    final rolesHandler = factory.createRolesHandler(filename: 'my_roles.yaml');
    final credentialsHandler = factory.createCredentialsHandler(
      filename: 'my_creds.yaml',
    );

    expect(rolesHandler.internal, isA<AuthRolesYaml>());
    expect(credentialsHandler.internal, isA<AuthCredentialsYaml>());

    await rolesHandler.start();
    await credentialsHandler.start();

    expect(
      File('${tempDir.path}/my_roles.yaml').path,
      contains('my_roles.yaml'),
    );
    expect(
      File('${tempDir.path}/my_creds.yaml').path,
      contains('my_creds.yaml'),
    );

    await rolesHandler.stop();
    await credentialsHandler.stop();
  });
}
