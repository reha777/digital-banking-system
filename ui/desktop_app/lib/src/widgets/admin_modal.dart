import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class AdminModal extends StatelessWidget {
  const AdminModal({
    super.key,
    required this.title,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryColor,
    this.width = 480,
    this.cancelLabel = 'Cancel',
  });

  final String title;
  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final Color? primaryColor;
  final double width;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final actionColor = primaryColor ?? AppTheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : const Color(0xFFF4F5FB);
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final borderColor = isDark ? const Color(0xFF303244) : const Color(0xFF9CA3AF);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.18),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(primaryLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      minimumSize: const Size.fromHeight(46),
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AdminModalField extends StatelessWidget {
  const AdminModalField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFFA4A7B7) : AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: isDark ? const Color(0xFF242438) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
          ),
        ),
      ],
    );
  }
}
