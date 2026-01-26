import 'dart:io';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final packagesDir = Directory('packages');
  if (!packagesDir.existsSync()) {
    return;
  }

  final coverageFiles = <String>[];

  for (final entity in packagesDir.listSync()) {
    if (entity is Directory) {
      final coverageDir = Directory(p.join(entity.path, 'coverage'));
      if (coverageDir.existsSync()) {
        final lcovFile = File(p.join(coverageDir.path, 'lcov.info'));
        if (lcovFile.existsSync()) {
          // Normalize to forward slashes for cross-platform consistency if needed,
          // but here we just need the paths for lcov_format.
          coverageFiles.add(p.relative(lcovFile.path));
        }
      }
    }
  }

  final format = switch (args) {
    ['--html'] => 'html',
    ['--ansi'] => 'ansi',
    ['--stats'] => 'stats',
    _ => 'html',
  };

  final result = Process.runSync(
    'lcov_format',
    ['-f', format, '-o', 'coverage', ...coverageFiles],
    runInShell: true, // This is required on Windows to find global CLI tools
  );

  if (args.contains('--ansi') || args.contains('--stats')) {
    stdout.write(result.stdout);
  }
}
