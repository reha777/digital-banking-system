import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_app/src/core/document_opener_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('safeDocumentFileName', () {
    test('removes path traversal and unsafe filename characters', () {
      expect(
        safeDocumentFileName(r'../../bad:<name>?.pdf', 'application/pdf'),
        'bad__name__.pdf',
      );
      expect(
        safeDocumentFileName(r'..\..\CON.txt', 'text/plain'),
        'document.txt',
      );
    });

    test('maps supported MIME types to extensions', () {
      expect(safeDocumentFileName('report', 'application/pdf'), 'report.pdf');
      expect(safeDocumentFileName('photo', 'image/jpeg'), 'photo.jpg');
      expect(safeDocumentFileName('image', 'image/png'), 'image.png');
      expect(safeDocumentFileName('notes', 'text/plain'), 'notes.txt');
    });

    test('preserves supported server-provided extensions', () {
      expect(safeDocumentFileName('photo.JPEG', 'image/jpeg'), 'photo.jpeg');
      expect(safeDocumentFileName('scan.PNG', 'image/png'), 'scan.png');
    });
  });

  test(
    'prepares native document in the requested temporary directory',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'document_open_test_',
      );
      addTearDown(() => directory.delete(recursive: true));

      final file = await prepareDocumentFile(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: '../statement.pdf',
        contentType: 'application/pdf',
        directory: directory,
      );

      expect(file.parent.path, directory.path);
      expect(file.path.toLowerCase(), endsWith('_statement.pdf'));
      expect(await file.readAsBytes(), [1, 2, 3]);
    },
  );
}
