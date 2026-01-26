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
}
