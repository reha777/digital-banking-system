import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/api_client.dart';
import 'notification_service.dart';

class DesktopNotificationBell extends StatefulWidget {
  const DesktopNotificationBell({
    super.key,
    required this.token,
    required this.onViewAll,
    required this.onTarget,
    this.onOpening,
  });
  final String token;
  final VoidCallback onViewAll;
  final ValueChanged<AdminNotification> onTarget;
  final VoidCallback? onOpening;
  @override
  State<DesktopNotificationBell> createState() =>
      _DesktopNotificationBellState();
}

class _DesktopNotificationBellState extends State<DesktopNotificationBell>
    with WidgetsBindingObserver {
  final _service = NotificationService(ApiClient());
  Timer? _timer;
  int _count = 0;
  List<AdminNotification> _latest = const [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final values = await Future.wait([
        _service.unreadCount(widget.token),
        _service.list(widget.token, pageSize: 5),
      ]);
      if (mounted) {
        setState(() {
          _count = values[0] as int;
          _latest = (values[1] as AdminNotificationPage).items;
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poll();
      _timer ??= Timer.periodic(const Duration(seconds: 25), (_) => _poll());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _all() async {
    await _service.markAllRead(widget.token);
    if (mounted) {
      setState(() {
        _count = 0;
        _latest = _latest.map((x) => x.asRead()).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    alignmentOffset: const Offset(-330, 8),
    menuChildren: [
      SizedBox(
        width: 370,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _count == 0 ? null : _all,
                    child: const Text('Mark all read'),
                  ),
                ],
              ),
              const Divider(),
              if (_latest.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('No notifications yet.'),
                )
              else
                for (final item in _latest)
                  ListTile(
                    dense: true,
                    onTap: () async {
                      if (!item.isRead) {
                        try {
                          await _service.markRead(widget.token, item.id);
                          if (mounted) {
                            setState(() {
                              _count = _count > 0 ? _count - 1 : 0;
                              _latest = _latest
                                  .map((x) => x.id == item.id ? x.asRead() : x)
                                  .toList();
                            });
                          }
                        } catch (_) {}
                      }
                      widget.onTarget(item);
                    },
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.isRead
                            ? FontWeight.w500
                            : FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: !item.isRead
                        ? const Icon(Icons.circle, size: 7, color: Colors.blue)
                        : null,
                  ),
              const Divider(),
              TextButton.icon(
                onPressed: widget.onViewAll,
                icon: const Icon(LucideIcons.arrowRight, size: 16),
                label: const Text('View all notifications'),
              ),
            ],
          ),
        ),
      ),
    ],
    builder: (_, controller, _) => Badge(
      isLabelVisible: _count > 0,
      label: Text(_count > 99 ? '99+' : '$_count'),
      child: IconButton.filledTonal(
        tooltip: 'Notifications',
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            widget.onOpening?.call();
            controller.open();
          }
        },
        icon: const Icon(LucideIcons.bell),
      ),
    ),
  );
}
