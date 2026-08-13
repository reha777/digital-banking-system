import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../widgets/app_summary_card.dart';
import '../admin_card_request_models.dart';

class CardRequestSummaryCards extends StatelessWidget {
  const CardRequestSummaryCards({super.key, required this.summary});
  final AdminCardRequestSummary summary;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: AppSummaryCard(
          title: 'Total requests',
          value: '${summary.totalRequests}',
          icon: LucideIcons.creditCard,
          tone: const Color(0xFF0066FF),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: AppSummaryCard(
          title: 'Pending',
          value: '${summary.pendingRequests}',
          icon: LucideIcons.hourglass,
          tone: const Color(0xFFF59E0B),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: AppSummaryCard(
          title: 'Approved',
          value: '${summary.approvedRequests}',
          icon: LucideIcons.clipboardCheck,
          tone: const Color(0xFF16A34A),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: AppSummaryCard(
          title: 'Rejected',
          value: '${summary.rejectedRequests}',
          icon: LucideIcons.xCircle,
          tone: const Color(0xFFDC2626),
        ),
      ),
    ],
  );
}
