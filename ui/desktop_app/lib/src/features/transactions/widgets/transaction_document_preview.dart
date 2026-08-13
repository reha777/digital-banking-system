import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/document_opener.dart';
import '../admin_transaction_models.dart';

class TransactionDocumentPreview extends StatelessWidget {
  const TransactionDocumentPreview({
    super.key,
    required this.document,
    required this.future,
  });
  final AdminTransactionDocument document;
  final Future<Uint8List> future;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) return const Text('Document could not be loaded.');
      final bytes = snapshot.requireData;
      final type = document.contentType.toLowerCase();
      if (type.startsWith('image/')) {
        return Image.memory(
          bytes,
          height: 260,
          width: double.infinity,
          fit: BoxFit.contain,
        );
      }
      if (type.startsWith('text/') ||
          document.fileName.toLowerCase().endsWith('.txt')) {
        return Container(
          constraints: const BoxConstraints(maxHeight: 260),
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            child: SelectableText(utf8.decode(bytes, allowMalformed: true)),
          ),
        );
      }
      return OutlinedButton(
        onPressed: () => openDocumentBytes(
          bytes: bytes,
          fileName: document.fileName,
          contentType: document.contentType,
        ),
        child: const Text('Open document'),
      );
    },
  );
}
