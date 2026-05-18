import 'package:flutter/material.dart';

import '../core/app_theme.dart';

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
    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFF7F7FA),
            boxShadow: [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 16,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              _NavItem(
                label: 'Home',
                iconAsset: 'assets/icons/navigation/home.png',
                fallbackIcon: Icons.home_outlined,
                isActive: currentIndex == 0,
                onTap: () => onSelected(0),
              ),
              _NavItem(
                label: 'My Cards',
                iconAsset: 'assets/icons/navigation/my_cards.png',
                fallbackIcon: Icons.credit_card_outlined,
                isActive: currentIndex == 1,
                onTap: () => onSelected(1),
              ),
              _NavItem(
                label: 'Statistics',
                fallbackIcon: Icons.pie_chart_outline,
                isActive: currentIndex == 2,
                onTap: () => onSelected(2),
              ),
              _NavItem(
                label: 'Settings',
                fallbackIcon: Icons.settings_outlined,
                isActive: currentIndex == 3,
                onTap: () => onSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.fallbackIcon,
    required this.isActive,
    required this.onTap,
    this.iconAsset,
  });

  final String label;
  final IconData fallbackIcon;
  final bool isActive;
  final VoidCallback onTap;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primary : AppTheme.textMuted;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, isActive ? -5 : 0, 0),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isActive
                      ? const [
                          BoxShadow(
                            color: Color(0x240066FF),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: iconAsset == null
                      ? Icon(fallbackIcon, size: 22, color: color)
                      : Image.asset(
                          iconAsset!,
                          width: 21,
                          height: 21,
                          color: color,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFF5F6FA),
        foregroundColor: AppTheme.textDark,
      ),
    );
  }
}
