import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:portico_auth_storage_yaml/src/io/yaml_file_watcher.dart';
import 'utils/writer.dart' show writeExternal;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hermetic_watcher_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('YamlFileWatcher', () {
    test('triggers callback on file creation/modification', () async {
      final file = File(p.join(tempDir.path, 'test.yaml'));
      String? lastContent;
      int callCount = 0;

      final watcher = YamlFileWatcher(
        file,
        onChange: (content) {
          lastContent = content;
          callCount++;
        },
      );

      await watcher.start();

      await writeExternal(file, 'key: value');

      // Give it some time to pick up the change
      await Future.delayed(Duration(milliseconds: 500));
      expect(callCount, 1);
      expect(lastContent, contains('key: value'));

      // Modify file
      await writeExternal(file, 'key: updated');

      await Future.delayed(Duration(milliseconds: 500));
      expect(callCount, 2);
      expect(lastContent, contains('key: updated'));

      await watcher.stop();
    });

    test('debounces redundant events with same content', () async {
      final file = File(p.join(tempDir.path, 'test.yaml'));
      int callCount = 0;

      await file.writeAsString('initial');

      final watcher = YamlFileWatcher(
        file,
        onChange: (_) {
          callCount++;
        },
      );

      await watcher.start();
      expect(callCount, 1); // Initial check

      // Same content (touch or rewrite same)
      await writeExternal(file, 'initial');
      await Future.delayed(Duration(milliseconds: 500));

      expect(callCount, 1, reason: 'Should not trigger for same content');

      await watcher.stop();
    });

    test('continues watching during activity', () async {
      final file = File(p.join(tempDir.path, 'test.yaml'));
      int callCount = 0;

      final watcher = YamlFileWatcher(
        file,
        onChange: (_) {
          callCount++;
        },
      );

      await watcher.start();
      expect(callCount, 0); // File doesn't exist yet

      // Simulate some activity.
      // We verify it picks up changes.

      for (int i = 0; i < 5; i++) {
        await file.writeAsString('content $i');
        await Future.delayed(Duration(milliseconds: 100));
      }

      await Future.delayed(Duration(milliseconds: 500));
      expect(callCount, greaterThan(0));

      await watcher.stop();
    });

    test('handles file read errors gracefully', () async {
      final file = File(p.join(tempDir.path, 'test.yaml'));
      await file.writeAsString('initial');

      String? lastContent;
      final watcher = YamlFileWatcher(file, onChange: (c) => lastContent = c);
      await watcher.start();
      expect(lastContent, 'initial');

      // Delete file to cause read error on next check (if check is triggered)
      await file.delete();

      // Manually trigger a check if we can, or just wait.
      // Since it's private, we rely on the directory event from deletion.
      await Future.delayed(Duration(milliseconds: 500));

      // Should still have last successful content
      expect(lastContent, 'initial');

      await watcher.stop();
    });
  });
}
