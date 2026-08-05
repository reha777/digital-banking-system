import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/app_theme.dart';
import '../../../core/theme_controller.dart';
import '../admin_section.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.userName,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.themeController,
    required this.onLogout,
    required this.compact,
  });
  final String userName;
  final AdminSection selectedSection;
  final ValueChanged<AdminSection> onSectionSelected;
  final ThemeController themeController;
  final VoidCallback onLogout;
  final bool compact;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    width: compact ? 84 : 260,
    color: const Color(0xFF111827),
    padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 22, compact ? 12 : 20, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.landmark, color: Colors.white),
            ),
            if (!compact) ...[
              const SizedBox(width: 12),
              const Text(
                'BankPick',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 32),
        _SidebarItem(
          icon: LucideIcons.layoutDashboard,
          title: 'Dashboard',
          active: selectedSection == AdminSection.dashboard,
          compact: compact,
          onTap: () => onSectionSelected(AdminSection.dashboard),
        ),
        _SidebarItem(
          icon: LucideIcons.receipt,
          title: 'Transactions',
          active: selectedSection == AdminSection.transactions,
          compact: compact,
          onTap: () => onSectionSelected(AdminSection.transactions),
        ),
        _SidebarItem(
          icon: LucideIcons.shieldAlert,
          title: 'Transaction Review',
          active: selectedSection == AdminSection.transactionReviews,
          compact: compact,
          onTap: () => onSectionSelected(AdminSection.transactionReviews),
        ),
        _SidebarItem(
          icon: LucideIcons.users,
          title: 'Customers',
          active: selectedSection == AdminSection.customers,
          compact: compact,
          onTap: () => onSectionSelected(AdminSection.customers),
        ),
        _SidebarItem(
          icon: LucideIcons.creditCard,
          title: 'Card Requests',
          active: selectedSection == AdminSection.cardRequests,
          compact: compact,
          onTap: () => onSectionSelected(AdminSection.cardRequests),
        ),
        const Spacer(),
        AnimatedBuilder(
          animation: themeController,
          builder: (context, _) {
            if (compact) {
              return IconButton(
                onPressed: () =>
                    themeController.toggleDarkMode(!themeController.isDarkMode),
                tooltip: themeController.isDarkMode
                    ? 'Use light mode'
                    : 'Use dark mode',
                icon: Icon(
                  themeController.isDarkMode
                      ? LucideIcons.moon
                      : LucideIcons.sun,
                  color: Colors.white70,
                ),
              );
            }
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    themeController.isDarkMode
                        ? LucideIcons.moon
                        : LucideIcons.sun,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Dark mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Switch(
                    value: themeController.isDarkMode,
                    onChanged: themeController.toggleDarkMode,
                  ),
                ],
              ),
            );
          },
        ),
        if (!compact)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF374151),
                  child: Icon(LucideIcons.user, color: Colors.white70),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    userName.isEmpty ? 'Admin' : userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (compact)
          IconButton(
            onPressed: onLogout,
            tooltip: 'Sign out $userName',
            icon: const Icon(LucideIcons.logOut, color: Colors.white70),
          )
        else
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(LucideIcons.logOut),
            label: const Text('Sign out'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
      ],
    ),
  );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.active,
    required this.compact,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final bool active;
  final bool compact;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final item = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: compact ? EdgeInsets.zero : null,
        horizontalTitleGap: compact ? 0 : 16,
        dense: true,
        onTap: onTap,
        leading: compact ? null : Icon(icon, color: Colors.white),
        title: compact
            ? Center(child: Icon(icon, color: Colors.white))
            : Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
      ),
    );
    return compact ? Tooltip(message: title, child: item) : item;
  }
}
