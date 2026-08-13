import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../card_models.dart';

class CardRequestTile extends StatelessWidget {
  const CardRequestTile({
    super.key,
    required this.request,
    this.documentUploadAction,
  });

  final CardRequestModel request;
  final Widget? documentUploadAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0x1A0066FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.credit_card, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.currency} card request',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request.status,
                      style: TextStyle(
                        color: request.requiresDocuments
                            ? const Color(0xFFB7791F)
                            : Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              ?documentUploadAction,
            ],
          ),
          if (request.requiresDocuments &&
              request.documentsRequestNote != null &&
              request.documentsRequestNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.documentsRequestNote!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (request.documents.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...request.documents.map(
              (document) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        document.fileName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
