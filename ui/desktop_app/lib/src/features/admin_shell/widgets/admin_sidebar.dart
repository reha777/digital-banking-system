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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.shieldCheck,
                color: Colors.white,
                size: 21,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Banking Admin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        Divider(color: Colors.white.withValues(alpha: .1), height: 1),
        const SizedBox(height: 18),
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
        _SidebarItem(
          icon: LucideIcons.coins,
          title: 'Loans',
          active: selectedSection == AdminSection.loans,
          compact: compact,
          onTap: () => onSectionSelected(AdminSection.loans),
        ),
        const SizedBox(height: 10),
        Divider(color: Colors.white.withValues(alpha: .1), height: 1),
        if (!compact) ...[
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 10),
            child: Text(
              'SYSTEM',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ] else
          const SizedBox(height: 12),
        _SidebarItem(
          icon: LucideIcons.barChart3,
          title: 'Reports',
          active: false,
          compact: compact,
          onTap: () => _unavailable(context, 'Reports'),
        ),
        _SidebarItem(
          icon: LucideIcons.settings,
          title: 'Settings',
          active: selectedSection == AdminSection.settings,
          compact: compact,
          onTap: () => onSectionSelected(AdminSection.settings),
        ),
        _SidebarItem(
          icon: LucideIcons.history,
          title: 'Audit Logs',
          active: false,
          compact: compact,
          onTap: () => _unavailable(context, 'Audit Logs'),
        ),
        const Spacer(),
        AnimatedBuilder(
          animation: themeController,
          builder: (context, _) => Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 8 : 12),
            decoration: BoxDecoration(
              color: const Color(0xFF172235),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: compact
                ? Column(
                    children: [
                      IconButton(
                        onPressed: () => themeController.toggleDarkMode(
                          !themeController.isDarkMode,
                        ),
                        tooltip: themeController.isDarkMode
                            ? 'Use light mode'
                            : 'Use dark mode',
                        icon: Icon(
                          themeController.isDarkMode
                              ? LucideIcons.sun
                              : LucideIcons.moon,
                          color: Colors.white70,
                        ),
                      ),
                      IconButton(
                        onPressed: onLogout,
                        tooltip: 'Sign out $userName',
                        icon: const Icon(
                          LucideIcons.logOut,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const CircleAvatar(
                        radius: 19,
                        backgroundColor: Color(0xFF334155),
                        child: Icon(
                          LucideIcons.user,
                          color: Colors.white70,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName.isEmpty ? 'Admin' : userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(
                              'Administrator',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => themeController.toggleDarkMode(
                          !themeController.isDarkMode,
                        ),
                        tooltip: themeController.isDarkMode
                            ? 'Use light mode'
                            : 'Use dark mode',
                        icon: Icon(
                          themeController.isDarkMode
                              ? LucideIcons.sun
                              : LucideIcons.moon,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                      IconButton(
                        onPressed: onLogout,
                        tooltip: 'Sign out',
                        icon: const Icon(
                          LucideIcons.logOut,
                          color: Colors.white54,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );

  void _unavailable(BuildContext context, String section) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$section is not available yet.')));
  }
}

class _SidebarItem extends StatefulWidget {
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
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final item = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.active
            ? AppTheme.primary
            : _hovered
            ? Colors.white.withValues(alpha: .07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: widget.compact ? EdgeInsets.zero : null,
        horizontalTitleGap: widget.compact ? 0 : 16,
        dense: true,
        onTap: widget.onTap,
        leading: widget.compact ? null : Icon(widget.icon, color: Colors.white),
        title: widget.compact
            ? Center(child: Icon(widget.icon, color: Colors.white))
            : Text(
                widget.title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: widget.active ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
      ),
    );
    final hoverable = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: item,
    );
    return widget.compact
        ? Tooltip(message: widget.title, child: hoverable)
        : hoverable;
  }
}
