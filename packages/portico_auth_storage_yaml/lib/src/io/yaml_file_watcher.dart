import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// A watcher that monitors a YAML file for changes and notifies a callback.
///
/// It uses a content hash to ensure that notifications are only sent
/// when the content actually changes, avoiding redundant updates.
class YamlFileWatcher {
  /// The file being watched.
  final File file;

  /// The callback to invoke when the file content changes.
  final void Function(String content) onChange;
  StreamSubscription? _subscription;
  String? _lastHash;
  bool _isWatching = false;

  /// Creates a [YamlFileWatcher] for the given [file].
  YamlFileWatcher(this.file, {required this.onChange});

  /// Starts watching the file.
  ///
  /// This will create the parent directory if it doesn't exist,
  /// perform an initial content check, and then start a file system
  /// watcher on the parent directory.
  Future<void> start() async {
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    _isWatching = true;

    // Initial check
    await _check();
    _watch(parent);
  }

  Future<void> _watch(Directory parent) async {
    if (!_isWatching) return;

    // If the directory does not exist, we cannot watch it.
    if (!parent.existsSync()) {
      stderr.writeln(
        'Warning: Parent directory does not exist. Watcher stopped.',
      );
      _isWatching = false;
      return;
    }

    try {
      _subscription = parent.watch().listen(
        (event) async {
          final eventPath = p.canonicalize(event.path);
          final targetPath = p.canonicalize(file.path);
          if (eventPath == targetPath) {
            await _check();
          }
        },
        onError: (e) async {
          stderr.writeln(
            'Warning: Directory watcher error: $e. Watcher stopped.',
          );

          await _subscription?.cancel();
          _subscription = null;
          _isWatching = false;
        },
      );
    } catch (e) {
      stderr.writeln(
        'Warning: Failed to start directory watcher: $e. Watcher stopped.',
      );
      await _subscription?.cancel();
      _subscription = null;
      _isWatching = false;
    }
  }

  Future<void> _check() async {
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();

      final currentHash = '${sha1.convert(content.codeUnits)}';
      if (currentHash != _lastHash) {
        _lastHash = currentHash;
        onChange(content);
      }
    } catch (e) {
      // Log or handle error (as per spec: maintain state)
      stderr.writeln('Error reading watched file ${file.path}: $e');
    }
  }

  /// Stops watching the file and cancels the subscription.
  Future<void> stop() async {
    _isWatching = false;
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Manually notifies the watcher of a known content update to avoid reloading.
  void notifyKnownContent(String content) {
    _lastHash = '${sha1.convert(content.codeUnits)}';
  }
}
