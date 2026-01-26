import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Example Verification', () {
    test('main.dart example exists and is valid Dart', () {
      final file = File('example/main.dart');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'example/main.dart should exist',
      );

      final result = Process.runSync('dart', ['analyze', 'example/main.dart']);
      expect(
        result.exitCode,
        equals(0),
        reason: 'example/main.dart should pass dart analyze',
      );
    });
  });
}
