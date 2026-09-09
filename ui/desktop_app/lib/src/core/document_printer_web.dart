import 'dart:typed_data';

import 'document_print_result.dart';

/// Printing is not wired up in the web shell; the admin uses Download instead.
Future<PrintOutcome> printDocumentBytes({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) async => PrintOutcome.unavailable;
