import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/app_theme.dart';
import '../transaction_models.dart';

class RecipientSelector extends StatelessWidget {
  const RecipientSelector({
    super.key,
    required this.recipients,
    required this.selected,
    required this.onAdd,
    required this.onSelected,
    this.loading = false,
    this.hasError = false,
  });

  final List<RecentRecipient> recipients;
  final RecentRecipient? selected;
  final VoidCallback onAdd;
  final ValueChanged<RecentRecipient> onSelected;
  final bool loading;
  final bool hasError;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Send to', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 14),
      SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 1 + (loading ? 3 : recipients.length),
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _RecipientItem(
                label: 'Add',
                initials: '',
                icon: LucideIcons.plus,
                onTap: onAdd,
              );
            }
            if (loading) {
              return const _LoadingRecipient();
            }
            final recipient = recipients[index - 1];
            return _RecipientItem(
              key: ValueKey('recipient-${recipient.accountId}'),
              label: recipient.firstName.isEmpty
                  ? recipient.accountNumber
                  : recipient.firstName,
              initials: recipient.initials,
              selected: selected?.accountId == recipient.accountId,
              onTap: () => onSelected(recipient),
            );
          },
        ),
      ),
      if (!loading && recipients.isEmpty)
        Text(
          hasError
              ? 'Recent recipients could not be loaded. You can still add one.'
              : 'Your recent recipients will appear here.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ],
  );
}

class _RecipientItem extends StatelessWidget {
  const _RecipientItem({
    super.key,
    required this.label,
    required this.initials,
    required this.onTap,
    this.icon,
    this.selected = false,
  });
  final String label;
  final String initials;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 64,
    child: InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: selected ? .22 : .10),
              border: Border.all(
                color: selected ? AppTheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, color: AppTheme.primary)
                : Text(
                    initials.isEmpty ? '?' : initials,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _LoadingRecipient extends StatelessWidget {
  const _LoadingRecipient();
  @override
  Widget build(BuildContext context) => Container(
    width: 58,
    height: 58,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
  );
}
