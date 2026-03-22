import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_storage_yaml/src/io/portico_auth_storage_yaml_io_handler.dart';
import 'package:portico_auth_storage_yaml/src/tokens_yaml.dart';
import 'package:portico_auth_storage_yaml/src/roles_yaml.dart';

import 'utils/writer.dart' show writeExternal;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'hermetic_io_adapter_test_',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AuthYamlIoHandler<AuthTokensYaml>', () {
    test('loads initial data from file', () async {
      final file = File(p.join(tempDir.path, 'tokens.yaml'));
      await file.writeAsString('''
kind: credentials
credentials:
  - serial: "123"
    user_id: "user1"
    name: "test"
    initial_time: "2023-01-01T00:00:00.000Z"
    last_time: "2023-01-01T00:00:00.000Z"
    counter: 1
''');

      final tokens = AuthTokensYaml();
      final adapter = AuthYamlIoHandler(
        tokens,
        file,
        onExternalUpdate: tokens.update,
        setOnYamlUpdate: (cb) => tokens.onYamlUpdate = cb,
      );
      await adapter.start();

      expect(adapter.internal.memory, contains('123+user1'));
      await adapter.stop();
    });

    test('writes data to file when updated', () async {
      final file = File(p.join(tempDir.path, 'tokens.yaml'));
      final tokens = AuthTokensYaml();
      final adapter = AuthYamlIoHandler(
        tokens,
        file,
        onExternalUpdate: tokens.update,
        setOnYamlUpdate: (cb) => tokens.onYamlUpdate = cb,
      );
      await adapter.start();

      await adapter.internal.recordRefreshToken(
        serial: '456',
        userId: 'user2',
        initial: DateTime.now(),
        lastUpdate: DateTime.now(),
        counter: 1,
        name: 'test2',
      );

      // Wait for write
      await Future.delayed(Duration(milliseconds: 200));
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), contains('serial: "456"'));

      await adapter.stop();
    });

    test('updates from file when changed externally', () async {
      final file = File(p.join(tempDir.path, 'tokens.yaml'));
      final tokens = AuthTokensYaml();
      final adapter = AuthYamlIoHandler(
        tokens,
        file,
        onExternalUpdate: tokens.update,
        setOnYamlUpdate: (cb) => tokens.onYamlUpdate = cb,
      );
      await adapter.start();

      expect(adapter.internal.memory, isEmpty);

      // External write using custom dart script
      await writeExternal(file, '''
kind: credentials
credentials:
  - serial: "ext"
    user_id: "u"
    name: "n"
    initial_time: "2023-01-01T00:00:00.000Z"
    last_time: "2023-01-01T00:00:00.000Z"
    counter: 5
''');

      // Poll for update
      for (int i = 0; i < 20; i++) {
        if (adapter.internal.memory.containsKey('ext+u')) break;
        await Future.delayed(Duration(milliseconds: 100));
      }

      expect(adapter.internal.memory, contains('ext+u'));

      await adapter.stop();
    });
  });

  group('AuthYamlIoHandler<AuthRolesYaml>', () {
    test('integration test: read, write, watch', () async {
      final file = File(p.join(tempDir.path, 'roles.yaml'));
      final roles = AuthRolesYaml();
      final adapter = AuthYamlIoHandler(
        roles,
        file,
        onExternalUpdate: roles.update,
        setOnYamlUpdate: (cb) => roles.onYamlUpdate = cb,
      );
      await adapter.start();

      await adapter.internal.createRole(
        Role(
          name: 'admin',
          displayName: 'Admin',
          isActive: true,
          description: 'desc',
        ),
      );
      await Future.delayed(Duration(milliseconds: 200));
      expect(await file.readAsString(), contains('name: admin'));

      await adapter.stop();
    });
  });
}
