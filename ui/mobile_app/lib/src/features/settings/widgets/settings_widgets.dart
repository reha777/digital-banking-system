import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../widgets/mobile_shell.dart';

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleIconButton(
          icon: Icons.arrow_back_ios_new,
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(letterSpacing: .7),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class SettingsNavigationTile extends StatelessWidget {
  const SettingsNavigationTile({
    super.key,
    required this.label,
    this.icon,
    this.value,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('settings-$label'),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppTheme.textMuted),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            if (value != null)
              Text(value!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            Icon(
              onTap == null ? Icons.lock_outline : Icons.chevron_right,
              size: 20,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
