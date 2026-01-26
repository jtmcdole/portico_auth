import 'dart:io';
import 'package:portico_auth_storage_yaml/src/io/atomic_file_writer.dart';

void main() async {
  final file = File('manual_test.yaml');
  final writer = AtomicFileWriter(file);
  await writer.writeString('verified: true\n');
  print('File written. Content: ${await file.readAsString()}');
  await file.delete();
}
