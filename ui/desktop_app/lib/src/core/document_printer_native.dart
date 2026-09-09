import 'dart:typed_data';

import 'package:printing/printing.dart';

import 'document_print_result.dart';

/// Sends an already generated report to the operating system's print dialog.
///
/// The first implementation shelled out to `Start-Process -Verb Print`. That
/// relies on the registered PDF handler exposing a `print` shell verb, and the
/// current Windows default handler (`MSEdgePDF`) registers only `open` and
/// `runas`. ShellExecute therefore failed with "The system cannot find the file
/// specified" and printing always reported itself unavailable.
///
/// The `printing` plugin instead hands the PDF bytes straight to the platform
/// printing subsystem — on Windows it rasterizes with pdfium and opens the
/// native print dialog — so it does not depend on any file association. The
/// bytes are the ones the worker already generated; nothing is re-rendered into
/// a different report.
Future<PrintOutcome> printDocumentBytes({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) async {
  final printed = await Printing.layoutPdf(
    name: fileName,
    onLayout: (_) async => bytes,
  );
  // false means the dialog opened and the admin dismissed it, which is a normal
  // outcome rather than a failure. Genuine subsystem errors throw.
  return printed ? PrintOutcome.printed : PrintOutcome.cancelled;
}
