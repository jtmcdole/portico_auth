/// This file is a utility for editing a file outside of the testing
/// process.

library;

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Usage: dart writer.dart <filepath> <base64_content>');
    exit(1);
  }

  final filePath = args[0];
  final base64Content = args[1];

  try {
    final content = utf8.decode(base64.decode(base64Content));
    File(filePath).writeAsStringSync(content);
    print('Successfully wrote to $filePath');
  } catch (e) {
    stderr.writeln('Error writing file: $e');
    exit(1);
  }
}

/// Callable outside.
Future<void> writeExternal(File file, String content) async {
  final possiblePaths = [
    p.join(Directory.current.path, 'test', 'utils', 'writer.dart'),
    p.join(
      Directory.current.path,
      'packages',
      'portico_auth_storage_yaml',
      'test',
      'utils',
      'writer.dart',
    ),
  ];

  String? writerScript;
  for (final path in possiblePaths) {
    if (File(path).existsSync()) {
      writerScript = path;
      break;
    }
  }

  if (writerScript == null) {
    throw Exception(
      'Could not find writer.dart script in any of the following locations: $possiblePaths',
    );
  }

  final base64Content = base64.encode(utf8.encode(content));

  final result = Process.runSync(Platform.executable, [
    writerScript,
    file.path,
    base64Content,
  ]);

  if (result.exitCode != 0) {
    throw Exception('External write failed: ${result.stderr}');
  }
}
