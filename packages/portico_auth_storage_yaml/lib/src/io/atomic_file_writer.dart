import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';

/// A utility for writing files atomically.
///
/// This class ensures that content is written to a temporary file first
/// and then renamed to the target file. This prevents file corruption
/// if a failure occurs during the write process.
class AtomicFileWriter {
  /// The target file to write to.
  final File file;

  final Random _random;

  /// Creates an [AtomicFileWriter] for the given [file].
  AtomicFileWriter(this.file, {@visibleForTesting Random? random})
    : _random = random ?? Random();

  /// Writes the given [contents] to the target [file] atomically.
  ///
  /// The content is first written to a temporary file and then renamed to
  /// the target file. This ensures that the target file is either fully
  /// updated or remains unchanged if a failure occurs during the write process.
  Future<void> writeString(String contents) async {
    // Generate a temporary file that we will write to first.
    final tempFile = File('${file.path}.${generateRandomString(5)}');
    try {
      await tempFile.writeAsString(contents, flush: true);
      await tempFile.rename(file.path);
    } catch (e) {
      // Cleanup temp file if it exists and rename failed
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  static final _chars =
      ('AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz${'1234567890' * 5}')
          .split('');

  @visibleForTesting
  String generateRandomString(int len) => [
    for (int i = 0; i < len; i++) _chars[_random.nextInt(_chars.length)],
  ].join();
}
