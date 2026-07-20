import 'package:file_picker/file_picker.dart';

Future<List<int>> getPlatformFileBytesImpl(dynamic platformFile) async {
  final file = platformFile as PlatformFile;
  return file.bytes ?? <int>[];
}

void ensureFilePickerInitialized() {
  // No initialization required.
}