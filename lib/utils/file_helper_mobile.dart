import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';

Future<List<int>> getPlatformFileBytesImpl(dynamic platformFile) async {
  final file = platformFile as PlatformFile;
  if (file.path != null) {
    return io.File(file.path!).readAsBytes();
  }
  return file.bytes ?? <int>[];
}

void ensureFilePickerInitialized() {
  // No-op for mobile/desktop (native platforms auto-initialize)
}
