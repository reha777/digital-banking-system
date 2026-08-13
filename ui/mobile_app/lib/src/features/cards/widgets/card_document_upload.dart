import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/document_picker.dart';
import '../card_models.dart';
import '../card_service.dart';

class CardDocumentUpload extends StatefulWidget {
  const CardDocumentUpload({
    super.key,
    required this.request,
    required this.token,
    required this.cardService,
    required this.onUploaded,
  });

  final CardRequestModel request;
  final String? token;
  final CardService cardService;
  final VoidCallback onUploaded;

  @override
  State<CardDocumentUpload> createState() => _CardDocumentUploadState();
}

class _CardDocumentUploadState extends State<CardDocumentUpload> {
  bool _isUploading = false;

  Future<void> _upload() async {
    if (_isUploading || !widget.request.requiresDocuments) {
      return;
    }

    setState(() => _isUploading = true);
    try {
      final upload = await showModalBottomSheet<PickedDocument>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _DocumentUploadSheet(),
      );
      if (upload == null || !mounted) {
        return;
      }

      final token = widget.token;
      if (token == null) {
        return;
      }

      await widget.cardService.uploadDocument(
        token: token,
        requestId: widget.request.id,
        fileName: upload.fileName,
        bytes: upload.bytes,
      );
      if (mounted) {
        widget.onUploaded();
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

class _DocumentUploadSheet extends StatefulWidget {
  const _DocumentUploadSheet();

  @override
  State<_DocumentUploadSheet> createState() => _DocumentUploadSheetState();
}

class _DocumentUploadSheetState extends State<_DocumentUploadSheet> {
  PickedDocument? _selectedFile;
  String? _errorMessage;

  Future<void> _pickFile() async {
    try {
      final file = await pickDocument();
      if (file == null || !mounted) {
        return;
      }

      setState(() {
        _selectedFile = file;
        _errorMessage = null;
      });
    } on DocumentPickerException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedFile = null;
        _errorMessage = error.message;
      });
    }
  }

  void _submit() {
    final file = _selectedFile;
    if (file == null) {
      setState(() => _errorMessage = 'Choose a document first.');
      return;
    }
    Navigator.of(context).pop(file);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload document',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.attach_file),
            label: const Text('Choose file'),
          ),
          if (_selectedFile != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkSurface
                    : const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFile!.fileName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatFileSize(_selectedFile!.size),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Upload Document'),
          ),
        ],
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(1)} KB';
  }
  return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
}
