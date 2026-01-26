import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:portico_auth_storage_yaml/src/io/atomic_file_writer.dart';

import 'utils/writer.dart' show writeExternal;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hermetic_atomic_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AtomicFileWriter', () {
    test('writes content successfully', () async {
      final file = File(p.join(tempDir.path, 'test.yaml'));
      final writer = AtomicFileWriter(file);

      await writer.writeString('content: atomic');

      expect(await file.readAsString(), 'content: atomic');
    });

    test('handles overwriting existing file', () async {
      final file = File(p.join(tempDir.path, 'test.yaml'));

      // Use shell to create initial content
      await writeExternal(file, 'initial: content');

      final writer = AtomicFileWriter(file);
      await writer.writeString('updated: content');

      expect(await file.readAsString(), contains('updated: content'));
    });

    test('uses random temp file and cleans it up', () async {
      final file = File(p.join(tempDir.path, 'test.yaml'));
      final writer = AtomicFileWriter(file);

      await writer.writeString('content');

      await Future.delayed(const Duration(seconds: 1));

      // Check that no temp files starting with test.yaml. are left behind
      final entities = await tempDir.list().toList();
      final tempFiles = entities
          .where((e) => e.path.contains('test.yaml.'))
          .toList();
      expect(
        tempFiles,
        isEmpty,
        reason: 'Temporary files should be cleaned up after atomic write',
      );
    });

    test('cleans up temp file on write error', () async {
      final file = File(p.join(tempDir.path, 'test.yaml'));
      // Create a directory where the file should be, to cause rename to fail (FileSystemException)
      await Directory(file.path).create();

      final writer = AtomicFileWriter(file);

      expect(
        () => writer.writeString('content'),
        throwsA(isA<FileSystemException>()),
      );

      await Future.delayed(Duration(seconds: 1));

      // final result = Process.runSync('Get-ChildItem', [tempDir.path]);
      // stdout.writeln('sup dawg: ${result.stdout}');

      // Check cleanup
      final entities = await tempDir.list().toList();
      final tempFiles = entities
          .where((e) => e.path.contains('test.yaml.'))
          .toList();
      expect(
        tempFiles,
        isEmpty,
        reason: 'Temporary file should be cleaned up even on failure',
      );
    });
  });
}
