import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../widgets/document_picker.dart';
import '../transaction_models.dart';
import '../transaction_service.dart';

class TransactionDocumentUpload extends StatefulWidget {
  const TransactionDocumentUpload({
    super.key,
    required this.transaction,
    required this.token,
    required this.transactionService,
    required this.onUploaded,
    required this.onMissingSession,
  });

  final BankTransaction transaction;
  final String? token;
  final TransactionService transactionService;
  final Future<void> Function() onUploaded;
  final VoidCallback onMissingSession;

  @override
  State<TransactionDocumentUpload> createState() =>
      _TransactionDocumentUploadState();
}

class _TransactionDocumentUploadState extends State<TransactionDocumentUpload> {
  bool _isUploading = false;

  Future<void> _upload() async {
    if (_isUploading || !widget.transaction.requiresDocuments) {
      return;
    }

    final token = widget.token;
    if (token == null) {
      widget.onMissingSession();
      return;
    }

    setState(() => _isUploading = true);
    try {
      final document = await pickDocument();
      if (document == null || !mounted) {
        return;
      }

      await widget.transactionService.uploadDocument(
        token: token,
        transactionId: widget.transaction.id,
        fileName: document.fileName,
        bytes: document.bytes,
      );
      await widget.onUploaded();
    } on DocumentPickerException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _isUploading ? null : _upload,
      child: const Text('Upload'),
    );
  }
}
