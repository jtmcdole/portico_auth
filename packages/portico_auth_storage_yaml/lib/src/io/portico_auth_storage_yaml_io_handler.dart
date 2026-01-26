import 'dart:io';
import 'atomic_file_writer.dart';
import 'yaml_file_watcher.dart';

/// A handler that manages the synchronization between an internal storage
/// instance and a YAML file on disk.
///
/// It uses an [AtomicFileWriter] to persist changes and a [YamlFileWatcher]
/// to react to external updates to the file.
class AuthYamlIoHandler<T> {
  /// The internal storage instance (e.g., `AuthTokensYaml`).
  final T internal;

  final AtomicFileWriter _writer;
  late final YamlFileWatcher _watcher;

  /// Creates an [AuthYamlIoHandler].
  ///
  /// [internal] is the storage instance being managed.
  /// [file] is the target YAML file on disk.
  /// [onExternalUpdate] is called when the file is updated externally.
  /// [setOnYamlUpdate] is used to register the writer's update callback
  /// with the [internal] storage.
  AuthYamlIoHandler(
    this.internal,
    File file, {
    required void Function(String) onExternalUpdate,
    required void Function(void Function(String)) setOnYamlUpdate,
  }) : _writer = AtomicFileWriter(file) {
    _watcher = YamlFileWatcher(file, onChange: onExternalUpdate);
    setOnYamlUpdate((content) {
      // Notify the watcher of the known content so it doesn't trigger a reload
      // when it sees the file change we are about to write.
      _watcher.notifyKnownContent(content);
      _writer.writeString(content);
    });
  }

  /// Starts the handler.
  ///
  /// If the target file exists, it is read and its content is passed to
  /// the external update callback. It then starts watching the file for
  /// changes.
  Future<void> start() async {
    if (await _writer.file.exists()) {
      _watcher.onChange(await _writer.file.readAsString());
    }
    await _watcher.start();
  }

  /// Stops the handler and its file watcher.
  Future<void> stop() async {
    await _watcher.stop();
  }
}
