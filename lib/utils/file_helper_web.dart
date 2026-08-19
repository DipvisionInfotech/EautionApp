import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';

Future<List<int>> getPlatformFileBytesImpl(dynamic platformFile) async {
  final file = platformFile as PlatformFile;
  return file.bytes ?? <int>[];
}

void ensureFilePickerInitialized() {
  // No initialization required.
}

void downloadFileBytesImpl(List<int> bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..target = 'blank'
    ..download = filename;
  anchor.click();
  html.Url.revokeObjectUrl(url);
}