import 'dart:io';
import 'dart:typed_data';

import 'document_open_result.dart';

const _tempFolderName = 'banking_app_documents';

String safeDocumentFileName(String fileName, String contentType) {
  final normalized = fileName.replaceAll('\\', '/');
  var name = normalized.split('/').last.trim();
  name = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  name = name.replaceAll(RegExp(r'[. ]+$'), '');

  final extension = _safeExtension(name, contentType);
  var stem = name;
  final dot = stem.lastIndexOf('.');
  if (dot > 0) stem = stem.substring(0, dot);
  stem = stem.replaceAll(RegExp(r'[^A-Za-z0-9 _.-]'), '_').trim();
  if (stem.isEmpty || _reservedWindowsNames.contains(stem.toUpperCase())) {
    stem = 'document';
  }
  if (stem.length > 80) stem = stem.substring(0, 80).trimRight();
  return '$stem$extension';
}

String _safeExtension(String fileName, String contentType) {
  final lower = fileName.toLowerCase();
  for (final extension in const ['.pdf', '.jpg', '.jpeg', '.png', '.txt']) {
    if (lower.endsWith(extension)) return extension;
  }
  return switch (contentType.toLowerCase().split(';').first.trim()) {
    'application/pdf' => '.pdf',
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'text/plain' => '.txt',
    _ => '.bin',
  };
}

const _reservedWindowsNames = {
  'CON',
  'PRN',
  'AUX',
  'NUL',
  'COM1',
  'COM2',
  'COM3',
  'COM4',
  'COM5',
  'COM6',
  'COM7',
  'COM8',
  'COM9',
  'LPT1',
  'LPT2',
  'LPT3',
  'LPT4',
  'LPT5',
  'LPT6',
  'LPT7',
  'LPT8',
  'LPT9',
};

Future<File> prepareDocumentFile({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
  Directory? directory,
}) async {
  final targetDirectory =
      directory ?? Directory('${Directory.systemTemp.path}/$_tempFolderName');
  await targetDirectory.create(recursive: true);
  if (directory == null) await _removeExpiredFiles(targetDirectory);
  final safeName = safeDocumentFileName(fileName, contentType);
  final uniqueName = '${DateTime.now().microsecondsSinceEpoch}_$safeName';
  final file = File(
    '${targetDirectory.path}${Platform.pathSeparator}$uniqueName',
  );
  return file.writeAsBytes(bytes, flush: true);
}

Future<DocumentOpenResult> openDocumentBytes({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) async {
  File? file;
  try {
    file = await prepareDocumentFile(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    await Process.start(file.path, const [], runInShell: true);
    return DocumentOpenResult(opened: true, savedPath: file.path);
  } catch (_) {
    return DocumentOpenResult(opened: false, savedPath: file?.path);
  }
}

Future<void> _removeExpiredFiles(Directory directory) async {
  final cutoff = DateTime.now().subtract(const Duration(days: 1));
  try {
    await for (final entity in directory.list()) {
      if (entity is File && (await entity.lastModified()).isBefore(cutoff)) {
        await entity.delete();
      }
    }
  } catch (_) {
    // Cleanup is best-effort and must never block opening a document.
  }
}
