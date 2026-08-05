import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../admin_card_request_models.dart';

class CardDocumentPreview extends StatelessWidget {
  const CardDocumentPreview({
    super.key,
    required this.document,
    required this.future,
  });
  final AdminCardRequestDocument document;
  final Future<Uint8List> future;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return Text(
          snapshot.error.toString(),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        );
      }
      final bytes = snapshot.requireData;
      final type = cardDocumentContentType(document);
      if (type.startsWith('image/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            height: 260,
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        );
      }
      if (type.startsWith('text/') ||
          document.fileName.toLowerCase().endsWith('.txt')) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 260),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: SelectableText(utf8.decode(bytes, allowMalformed: true)),
          ),
        );
      }
      return Text(
        'Document loaded (${formatDocumentBytes(bytes.length)}). Preview is available for image and text files.',
      );
    },
  );
}

String cardDocumentContentType(AdminCardRequestDocument document) {
  final type = document.contentType.toLowerCase();
  if (type.isNotEmpty && type != 'application/octet-stream') return type;
  final name = document.fileName.toLowerCase();
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.pdf')) return 'application/pdf';
  if (name.endsWith('.txt')) return 'text/plain';
  return 'application/octet-stream';
}

String formatDocumentBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
