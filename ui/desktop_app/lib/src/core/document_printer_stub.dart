import 'dart:typed_data';

import 'document_print_result.dart';

/// Prints a document through the platform print workflow.
Future<PrintOutcome> printDocumentBytes({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) async => PrintOutcome.unavailable;
