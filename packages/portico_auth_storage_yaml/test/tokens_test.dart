import 'package:portico_auth_storage_yaml/src/tokens_yaml.dart';
import 'package:test/test.dart';

void main() {
  test('Parses yaml', () async {
    final auth = AuthTokensYaml(
      yaml: '''
kind: roles
---
kind: credentials

credentials:
  - serial: 40ea03c0-12d6-41e9-bd75-22e006598795
    user_id: fu@fu.com
    name: rainbow supreme
    initial_time: 2025-12-29T18:14:40.000
    last_time: 2025-12-29T18:14:40.000
    counter: 1

  - serial: 50ea03c0-12d6-41e9-bd75-22e006598796
    user_id: bar@fu.com
    name: rainbow maximus
    initial_time: 2025-12-29T01:14:40.000
    last_time: 2025-12-29T19:14:40.000
    counter: 2
''',
    );

    expect(
      await auth.getRefreshTokenCounter(
        serial: '40ea03c0-12d6-41e9-bd75-22e006598795',
        userId: 'fu@fu.com',
      ),
      [1],
    );

    expect(
      await auth.getRefreshTokenCounter(
        serial: '50ea03c0-12d6-41e9-bd75-22e006598796',
        userId: 'bar@fu.com',
      ),
      [2],
    );
  });

  test('Updates yaml', () async {
    final auth = AuthTokensYaml(
      yaml: '''
kind: roles
---
kind: credentials

credentials:
  - serial: 40ea03c0-12d6-41e9-bd75-22e006598795
    user_id: fu@fu.com
    name: rainbow supreme
    initial_time: 2025-12-29T18:14:40.000
    last_time: 2025-12-29T18:14:40.000
    counter: 1

  - serial: 50ea03c0-12d6-41e9-bd75-22e006598796
    user_id: bar@fu.com
    name: rainbow maximus
    initial_time: 2025-12-29T01:14:40.000
    last_time: 2025-12-29T19:14:40.000
    counter: 2
''',
    );

    final updates = <String>[];
    auth.onYamlUpdate = (String yaml) => updates.add(yaml);

    await auth.updateRefreshTokenCounter(
      serial: '40ea03c0-12d6-41e9-bd75-22e006598795',
      userId: 'fu@fu.com',
      lastUpdate: DateTime(2025, 12, 30, 12),
      counter: 42,
    );

    expect(updates, hasLength(1));
    final auth2 = AuthTokensYaml(yaml: updates.first);

    expect(
      await auth2.getRefreshTokenCounter(
        serial: '40ea03c0-12d6-41e9-bd75-22e006598795',
        userId: 'fu@fu.com',
      ),
      [42],
    );
  });

  test('records new entries', () async {
    final auth = AuthTokensYaml();
    final updates = <String>[];
    auth.onYamlUpdate = (String yaml) => updates.add(yaml);

    await auth.recordRefreshToken(
      serial: '40ea03c0-12d6-41e9-bd75-22e006598795',
      userId: 'fu@fu.com',
      lastUpdate: DateTime(2025, 12, 30, 12),
      counter: 42,
      initial: DateTime(2025, 01, 01),
      name: 'jack rabbitington',
    );

    expect(updates, hasLength(1));
    expect(
      updates.first,
      contains('serial: 40ea03c0-12d6-41e9-bd75-22e006598795'),
    );
  });

  test('Invalidates tokens', () async {
    final auth = AuthTokensYaml(
      yaml: '''
kind: credentials

credentials:
  - serial: 40ea03c0-12d6-41e9-bd75-22e006598795
    user_id: fu@fu.com
    name: rainbow supreme
    initial_time: 2025-12-29T18:14:40.000
    last_time: 2025-12-29T18:14:40.000
    counter: 1

  - serial: 50ea03c0-12d6-41e9-bd75-22e006598796
    user_id: bar@fu.com
    name: rainbow maximus
    initial_time: 2025-12-29T01:14:40.000
    last_time: 2025-12-29T19:14:40.000
    counter: 2
''',
    );

    final updates = <String>[];
    auth.onYamlUpdate = (String yaml) => updates.add(yaml);

    await auth.invalidateRefreshToken(
      serial: '40ea03c0-12d6-41e9-bd75-22e006598795',
      userId: 'fu@fu.com',
    );

    expect(updates, hasLength(1));
    expect(
      updates.first,
      isNot(contains('40ea03c0-12d6-41e9-bd75-22e006598795')),
    );
  });

  test('Prevents YAML injection via serial and userId', () async {
    final auth = AuthTokensYaml();
    String? capturedYaml;
    auth.onYamlUpdate = (yaml) => capturedYaml = yaml;

    const maliciousSerial = 'serial1\n  - serial: injected_serial\n    user_id: injected@user.com\n    name: injected\n    initial_time: 2025-01-01T00:00:00.000\n    last_time: 2025-01-01T00:00:00.000\n    counter: 99';
    const maliciousUserId = 'user1\n    counter: 100';

    await auth.recordRefreshToken(
      serial: maliciousSerial,
      userId: maliciousUserId,
      initial: DateTime.parse('2025-01-01T00:00:00.000'),
      lastUpdate: DateTime.parse('2025-01-01T00:00:00.000'),
      counter: 1,
      name: 'normal name',
    );

    expect(capturedYaml, isNotNull);
    // Malicious strings should be quoted and escaped
    expect(capturedYaml, contains('serial: "serial1\\n  - serial: injected_serial\\n    user_id: injected@user.com\\n    name: injected\\n    initial_time: 2025-01-01T00:00:00.000\\n    last_time: 2025-01-01T00:00:00.000\\n    counter: 99"'));
    expect(capturedYaml, contains('user_id: "user1\\n    counter: 100"'));

    final auth2 = AuthTokensYaml(yaml: capturedYaml!);
    final counters = await auth2.getRefreshTokenCounter(
      serial: maliciousSerial,
      userId: maliciousUserId,
    );
    expect(counters, [1]);

    // Verify injected serial DOES NOT exist
    expect(
      await auth2.getRefreshTokenCounter(
        serial: 'injected_serial',
        userId: 'injected@user.com',
      ),
      [],
    );
  });
}
