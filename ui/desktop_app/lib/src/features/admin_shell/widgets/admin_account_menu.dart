import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../auth/auth_models.dart';
import 'admin_avatar.dart';

class AdminAccountMenu extends StatefulWidget {
  const AdminAccountMenu({
    super.key,
    required this.user,
    required this.showDetails,
    required this.onProfile,
    required this.onPreferences,
    required this.onSecurity,
    required this.onLogout,
    this.token,
    this.onOpening,
  });
  final AuthUser? user;
  final String? token;
  final bool showDetails;
  final VoidCallback onProfile, onPreferences, onSecurity, onLogout;
  final VoidCallback? onOpening;

  @override
  State<AdminAccountMenu> createState() => _AdminAccountMenuState();
}

class _AdminAccountMenuState extends State<AdminAccountMenu>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final _focusNode = FocusNode(debugLabel: 'Account popover');
  OverlayEntry? _entry;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  String get _name =>
      '${widget.user?.firstName ?? 'Admin'} ${widget.user?.lastName ?? ''}'
          .trim();
  String get _initials => [
    widget.user?.firstName ?? '',
    widget.user?.lastName ?? '',
  ].where((v) => v.isNotEmpty).map((v) => v[0]).join();
  bool get _open => _entry != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _scale = Tween(
      begin: .97,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _slide = Tween(
      begin: const Offset(0, -.025),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _entry?.remove();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() => _open ? _close() : _show();

  void _show() {
    if (_open) return;
    widget.onOpening?.call();
    _entry = OverlayEntry(builder: _overlay);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    setState(() {});
    _controller.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_open) _focusNode.requestFocus();
    });
  }

  Future<void> _close([VoidCallback? action]) async {
    final entry = _entry;
    if (entry == null) return;
    await _controller.reverse();
    entry.remove();
    _entry = null;
    if (mounted) setState(() {});
    action?.call();
  }

  Widget _overlay(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 24).clamp(240.0, 286.0);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 9),
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: Focus(
              focusNode: _focusNode,
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  _close();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: ScaleTransition(
                    scale: _scale,
                    alignment: Alignment.topRight,
                    child: _AccountPopover(
                      width: width,
                      name: _name,
                      initials: _initials,
                      email: widget.user?.email ?? '',
                      role: widget.user?.role.isNotEmpty == true
                          ? widget.user!.role
                          : 'Administrator',
                      onProfile: () => _close(widget.onProfile),
                      onPreferences: () => _close(widget.onPreferences),
                      onSecurity: () => _close(widget.onSecurity),
                      onLogout: () => _close(widget.onLogout),
                      user: widget.user,
                      token: widget.token,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: Tooltip(
      message: 'Account menu',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .055),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdminAvatar(user: widget.user, token: widget.token, radius: 18),
                if (widget.showDetails &&
                    MediaQuery.sizeOf(context).width >= 720) ...[
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Administrator',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                ],
                AnimatedRotation(
                  turns: _open ? .5 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: const Icon(LucideIcons.chevronDown, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AccountPopover extends StatelessWidget {
  const _AccountPopover({
    required this.width,
    required this.name,
    required this.initials,
    required this.email,
    required this.role,
    required this.onProfile,
    required this.onPreferences,
    required this.onSecurity,
    required this.onLogout,
    required this.user,
    required this.token,
  });
  final double width;
  final String name, initials, email, role;
  final VoidCallback onProfile, onPreferences, onSecurity, onLogout;
  final AuthUser? user;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF0F172A,
              ).withValues(alpha: dark ? .34 : .16),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Row(
                children: [
                  AdminAvatar(user: user, token: token, radius: 21),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          role,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: dark ? .35 : .5),
              ),
            ),
            const SizedBox(height: 6),
            _PopoverItem(
              icon: LucideIcons.user,
              title: 'Profile',
              subtitle: 'View and edit your profile',
              onTap: onProfile,
            ),
            _PopoverItem(
              icon: LucideIcons.slidersHorizontal,
              title: 'Preferences',
              subtitle: 'Personal settings',
              onTap: onPreferences,
            ),
            _PopoverItem(
              icon: LucideIcons.keyRound,
              title: 'Change Password',
              subtitle: 'Update your password',
              onTap: onSecurity,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: dark ? .35 : .5),
              ),
            ),
            const SizedBox(height: 6),
            _PopoverItem(
              icon: LucideIcons.logOut,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              onTap: onLogout,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PopoverItem extends StatefulWidget {
  const _PopoverItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_PopoverItem> createState() => _PopoverItemState();
}

class _PopoverItemState extends State<_PopoverItem> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final accent = widget.danger
        ? const Color(0xFFDC2626)
        : Theme.of(context).colorScheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? accent.withValues(alpha: .065)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: _hovered ? .12 : .08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.danger ? accent : null,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
