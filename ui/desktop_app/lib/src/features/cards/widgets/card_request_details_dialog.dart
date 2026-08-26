import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/app_status_badge.dart';
import '../admin_card_request_models.dart';
import 'card_document_preview.dart';

class CardRequestDetailsDialog extends StatefulWidget {
  const CardRequestDetailsDialog({
    super.key,
    required this.request,
    required this.onApprove,
    required this.onReject,
    required this.onRequestDocuments,
    required this.onSelectDocument,
  });
  final AdminCardRequest request;
  final Future<bool> Function() onApprove;
  final Future<bool> Function() onReject;
  final Future<bool> Function(String) onRequestDocuments;
  final Future<Uint8List> Function(AdminCardRequestDocument) onSelectDocument;
  @override
  State<CardRequestDetailsDialog> createState() =>
      _CardRequestDetailsDialogState();
}

class _CardRequestDetailsDialogState extends State<CardRequestDetailsDialog> {
  final _noteController = TextEditingController();
  AdminCardRequestDocument? _selectedDocument;
  Future<Uint8List>? _previewFuture;
  bool _busy = false;
  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _selectDocument(AdminCardRequestDocument document) {
    setState(() {
      _selectedDocument = document;
      _previewFuture = widget.onSelectDocument(document);
    });
  }

  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    final succeeded = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (succeeded) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final canReview = request.statusValue == 1 || request.statusValue == 4;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.creditCard),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Card Request - Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    tooltip: 'Close',
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    request.id,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 10),
                  AppStatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _Details(
                            label: 'Customer',
                            value: request.customerName,
                          ),
                          _Details(
                            label: 'Email',
                            value: request.customerEmail,
                          ),
                          _Details(
                            label: 'Cardholder',
                            value: request.cardholderName,
                          ),
                          _Details(label: 'Currency', value: request.currency),
                          _Details(label: 'Status', value: request.status),
                          _Details(
                            label: 'Document ID',
                            value: request.documentNumber,
                          ),
                          _Details(
                            label: 'Delivery',
                            value: request.deliveryAddress,
                          ),
                        ],
                      ),
                      if (request.note.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Customer note',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(request.note),
                      ],
                      if (request.statusValue == 2 &&
                          request.approvedAccountNumber != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Issued result',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: [
                            _Details(
                              label: 'Issued account',
                              value: request.approvedAccountNumber!,
                            ),
                            _Details(
                              label: 'Issued card',
                              value: request.approvedMaskedCardNumber ?? '-',
                            ),
                            _Details(
                              label: 'Card brand',
                              value: request.approvedCardBrand ?? '-',
                            ),
                            _Details(
                              label: 'Card status',
                              value: request.approvedCardStatus ?? '-',
                            ),
                            _Details(
                              label: 'Expiry',
                              value: request.approvedCardExpiryDate == null
                                  ? '-'
                                  : '${request.approvedCardExpiryDate!.month.toString().padLeft(2, '0')}/${request.approvedCardExpiryDate!.year}',
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Documents',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (request.documents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No uploaded documents yet.'),
                        ),
                      ...request.documents.map(
                        (document) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(LucideIcons.fileText),
                          title: Text(document.fileName),
                          subtitle: Text(
                            '${document.contentType} · ${formatDocumentBytes(document.sizeBytes)}',
                          ),
                          trailing: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _selectDocument(document),
                            icon: const Icon(LucideIcons.eye, size: 18),
                            label: const Text('Preview'),
                          ),
                        ),
                      ),
                      if (_selectedDocument != null) ...[
                        const SizedBox(height: 12),
                        CardDocumentPreview(
                          document: _selectedDocument!,
                          future: _previewFuture!,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Message for customer',
                          prefixIcon: Icon(LucideIcons.messageSquare),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_busy)
                const LinearProgressIndicator()
              else
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: canReview
                          ? () => _run(
                              () => widget.onRequestDocuments(
                                _noteController.text.trim(),
                              ),
                            )
                          : null,
                      icon: const Icon(LucideIcons.filePlus, size: 18),
                      label: const Text('Request documents'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                      onPressed: canReview ? () => _run(widget.onReject) : null,
                      icon: const Icon(LucideIcons.x, size: 18),
                      label: const Text('Reject'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.success,
                      ),
                      onPressed: canReview
                          ? () => _run(widget.onApprove)
                          : null,
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: const Text('Approve'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value),
      ],
    ),
  );
}
