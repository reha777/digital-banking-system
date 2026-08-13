import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../card_models.dart';
import '../card_service.dart';
import 'card_document_upload.dart';
import 'card_request_tile.dart';

class CardRequestsPanel extends StatelessWidget {
  const CardRequestsPanel({
    super.key,
    required this.requests,
    required this.token,
    required this.cardService,
    required this.onDocumentUploaded,
  });

  final List<CardRequestModel> requests;
  final String? token;
  final CardService cardService;
  final VoidCallback onDocumentUploaded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Card requests', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...requests.map(
            (request) => CardRequestTile(
              request: request,
              documentUploadAction: request.requiresDocuments
                  ? CardDocumentUpload(
                      request: request,
                      token: token,
                      cardService: cardService,
                      onUploaded: onDocumentUploaded,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
