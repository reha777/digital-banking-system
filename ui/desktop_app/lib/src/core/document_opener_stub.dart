import 'dart:typed_data';

import 'document_open_result.dart';

Future<DocumentOpenResult> openDocumentBytes({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) async {
  return const DocumentOpenResult(opened: false);
}
