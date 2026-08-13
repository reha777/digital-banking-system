import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

const documentAllowedExtensions = ['jpg', 'jpeg', 'png', 'pdf', 'txt'];
const maximumDocumentSizeBytes = 5 * 1024 * 1024;

class PickedDocument {
  const PickedDocument({
    required this.fileName,
    required this.bytes,
    required this.size,
  });

  final String fileName;
  final Uint8List bytes;
  final int size;
}

class DocumentPickerException implements Exception {
  const DocumentPickerException(this.message);

  final String message;
}

Future<PickedDocument?> pickDocument() async {
  final result = await FilePicker.pickFiles(
    allowMultiple: false,
    withData: true,
    type: FileType.custom,
    allowedExtensions: documentAllowedExtensions,
  );

  final file = result?.files.single;
  if (file == null) {
    return null;
  }

  if (file.size > maximumDocumentSizeBytes) {
    throw const DocumentPickerException('Document can be no larger than 5 MB.');
  }

  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw const DocumentPickerException('Selected file could not be loaded.');
  }

  if (bytes.length > maximumDocumentSizeBytes) {
    throw const DocumentPickerException('Document can be no larger than 5 MB.');
  }

  return PickedDocument(fileName: file.name, bytes: bytes, size: file.size);
}
