import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.rows = 6});
  final int rows;
  @override
  Widget build(BuildContext context) => ListView.separated(
    itemCount: rows,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, _) => Container(
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.onRetry,
    this.message = 'Data could not be loaded.',
  });
  final VoidCallback onRetry;
  final String message;
  @override
  Widget build(BuildContext context) => _PageMessage(
    icon: LucideIcons.alertCircle,
    title: 'Something went wrong',
    message: message,
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(LucideIcons.refreshCw, size: 18),
      label: const Text('Try again'),
    ),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onReset,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onReset;
  @override
  Widget build(BuildContext context) => _PageMessage(
    icon: icon,
    title: title,
    message: message,
    action: onReset == null
        ? null
        : TextButton.icon(
            onPressed: onReset,
            icon: const Icon(LucideIcons.rotateCcw, size: 18),
            label: const Text('Clear filters'),
          ),
  );
}

class _PageMessage extends StatelessWidget {
  const _PageMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}
