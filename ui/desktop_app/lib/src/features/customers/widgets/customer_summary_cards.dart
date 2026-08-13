import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../widgets/app_summary_card.dart';
import '../admin_customer_models.dart';

class CustomerSummaryCards extends StatelessWidget {
  const CustomerSummaryCards({super.key, required this.summary});
  final AdminCustomerSummary summary;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: AppSummaryCard(
          title: 'Total customers',
          value: '${summary.totalCustomers}',
          icon: LucideIcons.users,
          tone: const Color(0xFF0066FF),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: AppSummaryCard(
          title: 'Active',
          value: '${summary.activeCustomers}',
          icon: LucideIcons.shieldCheck,
          tone: const Color(0xFF16A34A),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: AppSummaryCard(
          title: 'Inactive / blocked',
          value: '${summary.inactiveCustomers + summary.blockedCustomers}',
          icon: LucideIcons.userX,
          tone: const Color(0xFFF97316),
        ),
      ),
    ],
  );
}
