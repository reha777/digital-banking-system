import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';

import '../../core/api_client.dart';
import '../auth/auth_session.dart';
import 'notification_model.dart';
import 'notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.session,
    this.onOpenTarget,
  });
  final AuthSession session;
  final ValueChanged<AppNotification>? onOpenTarget;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationService _service;
  List<AppNotification> _items = const [];
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = NotificationService(ApiClient(), widget.session);
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final value = await _service.getNotifications(pageSize: 100);
      if (mounted) setState(() => _items = value.items);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Notifications could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _read(AppNotification item) async {
    if (!item.isRead) {
      try {
        await _service.markRead(item.id);
        if (mounted) {
          setState(
            () => _items = _items
                .map((x) => x.id == item.id ? x.asRead() : x)
                .toList(),
          );
        }
      } catch (_) {}
    }
    widget.onOpenTarget?.call(item);
  }

  Future<void> _readAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.markAllRead();
      if (mounted) {
        setState(() => _items = _items.map((x) => x.asRead()).toList());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _time(DateTime value) {
    final difference = DateTime.now().toUtc().difference(value);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays == 1) return 'Yesterday';
    return '${value.day}.${value.month}.${value.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        if (_items.any((x) => !x.isRead))
          TextButton(
            onPressed: _busy ? null : _readAll,
            child: const Text('Mark all read'),
          ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              ],
            ),
          )
        : _items.isEmpty
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.bell, size: 42),
                SizedBox(height: 12),
                Text('No notifications yet.'),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final item = _items[index];
                return Material(
                  color: item.isRead
                      ? Theme.of(context).colorScheme.surfaceContainerLow
                      : Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    onTap: () => _read(item),
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      child: Icon(
                        item.type.contains('Loan')
                            ? LucideIcons.landmark
                            : item.type.contains('Card')
                            ? LucideIcons.creditCard
                            : LucideIcons.arrowLeftRight,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.isRead
                            ? FontWeight.w600
                            : FontWeight.w800,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(item.message),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_time(item.createdAtUtc)),
                        if (!item.isRead)
                          Container(
                            margin: const EdgeInsets.only(top: 7),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
  );
}

class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    required this.session,
    required this.onTap,
  });
  final AuthSession session;
  final Future<void> Function() onTap;
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  late final NotificationService _service;
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = NotificationService(ApiClient(), widget.session);
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!widget.session.isAuthenticated) return;
    try {
      final count = await _service.unreadCount();
      if (mounted) setState(() => _count = count);
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
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: _count > 0,
    label: Text(_count > 99 ? '99+' : '$_count'),
    child: IconButton.filledTonal(
      icon: const Icon(LucideIcons.bell),
      tooltip: 'Notifications',
      onPressed: () async {
        await widget.onTap();
        await _poll();
      },
    ),
  );
}
