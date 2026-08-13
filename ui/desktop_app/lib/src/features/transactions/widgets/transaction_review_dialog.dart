import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/app_theme.dart';
import '../../../core/document_opener.dart';
import '../../../widgets/app_status_badge.dart';
import '../admin_transaction_models.dart';
import 'transaction_document_preview.dart';

class TransactionReviewDialog extends StatefulWidget {
  const TransactionReviewDialog({
    super.key,
    required this.transaction,
    required this.onRequestDocuments,
    required this.onApprove,
    required this.onReject,
    required this.onDownloadDocument,
  });
  final AdminTransaction transaction;
  final Future<bool> Function(String note) onRequestDocuments;
  final Future<bool> Function(String note) onApprove;
  final Future<bool> Function(String note) onReject;
  final Future<Uint8List> Function(AdminTransactionDocument document)
  onDownloadDocument;

  @override
  State<TransactionReviewDialog> createState() =>
      _TransactionReviewDialogState();
}

class _TransactionReviewDialogState extends State<TransactionReviewDialog> {
  final _noteController = TextEditingController();
  AdminTransactionDocument? _selected;
  Future<Uint8List>? _preview;
  String? _activeAction;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openDocument(AdminTransactionDocument document) async {
    final future = widget.onDownloadDocument(document);
    setState(() {
      _selected = document;
      _preview = future;
    });
    try {
      final bytes = await future;
      await openDocumentBytes(
        bytes: bytes,
        fileName: document.fileName,
        contentType: document.contentType,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document could not be opened.')),
        );
      }
    }
  }

  Future<void> _submit(String action) async {
    if (_activeAction != null) return;
    final note = _noteController.text.trim();
    if (action == 'documents' && note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a reason for requesting documents.'),
        ),
      );
      return;
    }
    if (action != 'documents') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            action == 'approve'
                ? 'Approve transaction?'
                : 'Reject transaction?',
          ),
          content: const Text('This decision cannot be easily reversed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action == 'approve' ? 'Approve' : 'Reject'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _activeAction = action);
    final success = switch (action) {
      'approve' => await widget.onApprove(note),
      'reject' => await widget.onReject(note),
      _ => await widget.onRequestDocuments(note),
    };
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() => _activeAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final canReview =
        transaction.statusValue == 1 || transaction.statusValue == 5;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.shieldAlert, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Transaction Review - Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: _activeAction == null
                        ? () => Navigator.pop(context)
                        : null,
                    tooltip: 'Close',
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    transaction.referenceNumber,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 10),
                  AppStatusBadge(status: transaction.status),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final information = _ReviewPanel(
                        title: 'Transaction information',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 18,
                          children: [
                            _Info('Reference', transaction.referenceNumber),
                            _Info('Status', transaction.status),
                            _Info(
                              'Amount',
                              '\$${transaction.amount.toStringAsFixed(2)}',
                            ),
                            _Info(
                              'From',
                              transaction.sourceCustomerName ??
                                  transaction.sourceAccountNumber ??
                                  transaction.accountNumber,
                            ),
                            _Info(
                              'To',
                              transaction.destinationCustomerName ??
                                  transaction.destinationAccountNumber ??
                                  '-',
                            ),
                            _Info(
                              'Reason',
                              transaction.reviewReason ?? 'High value transfer',
                            ),
                          ],
                        ),
                      );
                      final documents = _ReviewPanel(
                        title: 'Documents',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (transaction.documents.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('No uploaded proof documents yet.'),
                              )
                            else
                              ...transaction.documents.map(
                                (document) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(LucideIcons.fileText),
                                  title: Text(document.fileName),
                                  subtitle: Text(document.contentType),
                                  trailing: OutlinedButton.icon(
                                    onPressed: () => _openDocument(document),
                                    icon: const Icon(LucideIcons.eye, size: 18),
                                    label: const Text('Preview'),
                                  ),
                                ),
                              ),
                            if (_selected != null && _preview != null)
                              TransactionDocumentPreview(
                                document: _selected!,
                                future: _preview!,
                              ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _noteController,
                              enabled: _activeAction == null,
                              maxLines: 3,
                              maxLength: 500,
                              decoration: const InputDecoration(
                                labelText: 'Admin note',
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      );
                      if (constraints.maxWidth < 720) {
                        return Column(
                          children: [
                            information,
                            const SizedBox(height: 14),
                            documents,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: information),
                          const SizedBox(width: 14),
                          Expanded(child: documents),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: canReview && _activeAction == null
                        ? () => _submit('documents')
                        : null,
                    icon: _ActionIcon(
                      active: _activeAction == 'documents',
                      icon: LucideIcons.fileUp,
                    ),
                    label: const Text('Request documents'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.error,
                    ),
                    onPressed: canReview && _activeAction == null
                        ? () => _submit('reject')
                        : null,
                    icon: _ActionIcon(
                      active: _activeAction == 'reject',
                      icon: LucideIcons.x,
                    ),
                    label: const Text('Reject'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.success,
                    ),
                    onPressed: canReview && _activeAction == null
                        ? () => _submit('approve')
                        : null,
                    icon: _ActionIcon(
                      active: _activeAction == 'approve',
                      icon: LucideIcons.check,
                    ),
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

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).dividerTheme.color ?? AppTheme.border,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value),
      ],
    ),
  );
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.active, required this.icon});
  final bool active;
  final IconData icon;
  @override
  Widget build(BuildContext context) => active
      ? const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(icon, size: 18);
}
