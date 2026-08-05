// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> openDocumentBytes({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) async {
  final blob = html.Blob([bytes], contentType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');

  Future<void>.delayed(const Duration(minutes: 1), () {
    html.Url.revokeObjectUrl(url);
  });

  return true;
}
