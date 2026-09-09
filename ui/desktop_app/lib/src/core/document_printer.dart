export 'document_printer_stub.dart'
    if (dart.library.html) 'document_printer_web.dart'
    if (dart.library.io) 'document_printer_native.dart';
