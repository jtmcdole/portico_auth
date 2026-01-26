import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:test/test.dart';

void main() {
  test('converts from json', () {
    final set = TokenSet.fromJson({
      'name': 'asdf',
      'refresh_token': '1234',
      'access_token': '5678',
      'expiration_date': '2025-12-29T08:34:16.000',
    });

    expect(set.accessToken, '5678');
    expect(set.accessToken, '5678');
    expect(set.expirationDate, DateTime(2025, 12, 29, 8, 34, 16));
    expect(set.refreshToken, '1234');
    expect(set.accessToken, '5678');
  });

  test('converts to json', () {
    final set = TokenSet(
      name: 'asdf',
      refreshToken: '1234',
      accessToken: '5678',
      expirationDate: DateTime(2025, 12, 29, 8, 34, 16),
    );

    final json = set.toJson();

    expect(json, {
      'name': 'asdf',
      'refresh_token': '1234',
      'access_token': '5678',
      'expiration_date': '2025-12-29T08:34:16.000',
    });
  });

  test('returns props', () {
    final set = TokenSet(
      name: 'asdf',
      refreshToken: '1234',
      accessToken: '5678',
      expirationDate: DateTime(2025, 12, 29, 8, 34, 16),
    );

    expect(set.props, [
      'asdf',
      '1234',
      '5678',
      DateTime(2025, 12, 29, 8, 34, 16),
    ]);
  });
}
