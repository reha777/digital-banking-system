import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/app_theme.dart';

/// Keeps root tab state mounted while laying out and painting only one tab.
class MobileTabStack extends StatelessWidget {
  const MobileTabStack({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(index: currentIndex, children: children);
  }
}

class MobileShell extends StatelessWidget {
  const MobileShell({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: keyboardVisible
          ? null
          : SafeArea(
              top: false,
              child: Container(
                key: const ValueKey('mobile-bottom-navigation'),
                height: 74,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface
                      : const Color(0xFFF7F7FA),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0x33000000)
                          : const Color(0x12000000),
                      blurRadius: 16,
                      offset: Offset(0, -5),
                    ),
                  ],
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? const Color(0x14FFFFFF)
                          : const Color(0x0F12182B),
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: _indicatorAlignment(currentIndex),
                          child: FractionallySizedBox(
                            widthFactor: .25,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primary.withValues(
                                        alpha: isDark ? .22 : .13,
                                      ),
                                      AppTheme.primary.withValues(
                                        alpha: isDark ? .11 : .06,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(
                                      alpha: isDark ? .24 : .15,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(
                                        alpha: isDark ? .12 : .08,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _NavItem(
                          label: 'Home',
                          icon: LucideIcons.house,
                          isActive: currentIndex == 0,
                          onTap: () => onSelected(0),
                        ),
                        _NavItem(
                          label: 'My Cards',
                          icon: LucideIcons.creditCard,
                          isActive: currentIndex == 1,
                          onTap: () => onSelected(1),
                        ),
                        _NavItem(
                          label: 'Statistics',
                          icon: LucideIcons.chartNoAxesCombined,
                          isActive: currentIndex == 2,
                          onTap: () => onSelected(2),
                        ),
                        _NavItem(
                          label: 'Settings',
                          icon: LucideIcons.settings,
                          isActive: currentIndex == 3,
                          onTap: () => onSelected(3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Alignment _indicatorAlignment(int index) => switch (index) {
    0 => Alignment.centerLeft,
    1 => const Alignment(-1 / 3, 0),
    2 => const Alignment(1 / 3, 0),
    _ => Alignment.centerRight,
  };
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primary : AppTheme.textMuted;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashFactory: NoSplash.splashFactory,
        hoverColor: AppTheme.primary.withValues(alpha: 0.05),
        highlightColor: AppTheme.primary.withValues(alpha: 0.08),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                scale: isActive ? 1 : 0.94,
                child: SizedBox(
                  width: 38,
                  height: 30,
                  child: Center(child: Icon(icon, size: 21, color: color)),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: isDark
            ? AppTheme.darkSurface
            : const Color(0xFFF5F6FA),
        foregroundColor: isDark ? Colors.white : AppTheme.textDark,
      ),
    );
  }
}
