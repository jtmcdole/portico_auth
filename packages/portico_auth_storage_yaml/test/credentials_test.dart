import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_storage_yaml/src/credentials_yaml.dart';
import 'package:test/test.dart';

void main() {
  test('Parses yaml', () async {
    final auth = AuthCredentialsYaml(
      yaml: '''
kind: user_credentials
credentials:
  - user_id: user1@example.com
    salt: somesalt1
    hash: somehash1
    creation_time: 2025-01-01T12:00:00.000
  - user_id: user2@example.com
    salt: somesalt2
    hash: somehash2
    creation_time: 2025-01-02T12:00:00.000
''',
    );

    final cred1 = await auth.getPasswordHash('user1@example.com');
    expect(cred1.hash, 'somehash1');
    expect(cred1.salt, 'somesalt1');

    final cred2 = await auth.getPasswordHash('user2@example.com');
    expect(cred2.hash, 'somehash2');
    expect(cred2.salt, 'somesalt2');
  });

  test('Creates user and persists to yaml', () async {
    final auth = AuthCredentialsYaml();
    final updates = <String>[];
    auth.onYamlUpdate = (String yaml) => updates.add(yaml);

    final now = DateTime.now();
    await auth.createUser(
      userId: 'newuser@example.com',
      salt: 'newsalt',
      hash: 'newhash',
      creationTime: now,
    );

    expect(updates, hasLength(1));
    expect(updates.first, contains('kind: user_credentials'));
    expect(updates.first, contains('user_id: newuser@example.com'));
    expect(updates.first, contains('salt: newsalt'));
    expect(updates.first, contains('hash: newhash'));

    final auth2 = AuthCredentialsYaml(yaml: updates.first);
    final cred = await auth2.getPasswordHash('newuser@example.com');
    expect(cred.hash, 'newhash');
    expect(cred.salt, 'newsalt');
  });

  test('Updates password', () async {
    final auth = AuthCredentialsYaml(
      yaml: '''
kind: user_credentials
credentials:
  - user_id: user1@example.com
    salt: oldsalt
    hash: oldhash
    creation_time: 2025-01-01T12:00:00.000
''',
    );

    final updates = <String>[];
    auth.onYamlUpdate = (String yaml) => updates.add(yaml);

    await auth.updatePassword(
      userId: 'user1@example.com',
      salt: 'newsalt',
      hash: 'newhash',
    );

    expect(updates, hasLength(1));
    expect(updates.last, contains('hash: newhash'));
    expect(updates.last, contains('salt: newsalt'));

    final auth2 = AuthCredentialsYaml(yaml: updates.last);
    final cred = await auth2.getPasswordHash('user1@example.com');
    expect(cred.hash, 'newhash');
    expect(cred.salt, 'newsalt');
  });

  test('Deletes user', () async {
    final auth = AuthCredentialsYaml(
      yaml: '''
kind: user_credentials
credentials:
  - user_id: user1@example.com
    salt: somesalt
    hash: somehash
    creation_time: 2025-01-01T12:00:00.000
''',
    );

    final updates = <String>[];
    auth.onYamlUpdate = (String yaml) => updates.add(yaml);

    await auth.deleteUser('user1@example.com');

    expect(updates, hasLength(1));
    expect(updates.last, isNot(contains('user1@example.com')));

    final auth2 = AuthCredentialsYaml(yaml: updates.last);
    expect(
      () => auth2.getPasswordHash('user1@example.com'),
      throwsA(isA<UserDoesNotExistException>()),
    );
  });

  test('Exceptions for existing/missing users', () async {
    final auth = AuthCredentialsYaml(
      yaml: '''
kind: user_credentials
credentials:
  - user_id: user1@example.com
    salt: somesalt
    hash: somehash
    creation_time: 2025-01-01T12:00:00.000
''',
    );

    expect(
      () => auth.createUser(
        userId: 'user1@example.com',
        salt: 's',
        hash: 'h',
        creationTime: DateTime.now(),
      ),
      throwsA(isA<UserAlreadyExistsException>()),
    );
  });

  test('updatePassword and deleteUser handle missing users', () async {
    final auth = AuthCredentialsYaml();

    expect(
      () => auth.updatePassword(
        userId: 'missing@example.com',
        salt: 's',
        hash: 'h',
      ),
      throwsA(isA<UserDoesNotExistException>()),
    );

    expect(
      () => auth.deleteUser('missing@example.com'),
      throwsA(isA<UserDoesNotExistException>()),
    );

    expect(
      () => auth.getPasswordHash('missing@example.com'),
      throwsA(isA<UserDoesNotExistException>()),
    );
  });
}
