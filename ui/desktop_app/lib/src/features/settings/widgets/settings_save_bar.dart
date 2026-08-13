import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SettingsSaveBar extends StatelessWidget {
  const SettingsSaveBar({
    super.key,
    required this.dirty,
    required this.saving,
    required this.onSave,
  });
  final bool dirty, saving;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: dirty ? 1 : 0,
        child: Text(
          'Unsaved changes',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      const SizedBox(width: 16),
      ElevatedButton.icon(
        onPressed: dirty && !saving ? onSave : null,
        icon: saving
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(LucideIcons.save, size: 17),
        label: Text(saving ? 'Saving...' : 'Save Changes'),
      ),
    ],
  );
}
