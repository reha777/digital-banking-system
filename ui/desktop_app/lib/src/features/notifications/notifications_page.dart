import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/api_client.dart';
import 'notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.token,
    required this.onTarget,
  });
  final String token;
  final ValueChanged<AdminNotification> onTarget;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationService(ApiClient());
  List<AdminNotification> _items = const [];
  bool _loading = true, _unreadOnly = false;
  String? _error;
  int _page = 1, _total = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.list(
        widget.token,
        page: _page,
        unreadOnly: _unreadOnly,
      );
      if (mounted) {
        setState(() {
          _items = result.items;
          _total = result.totalCount;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Notifications could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _read(AdminNotification item) async {
    if (!item.isRead) {
      try {
        await _service.markRead(widget.token, item.id);
        if (mounted) {
          setState(
            () => _items = _items
                .map((value) => value.id == item.id ? value.asRead() : value)
                .toList(),
          );
        }
      } catch (_) {}
    }
    widget.onTarget(item);
  }

  Future<void> _all() async {
    await _service.markAllRead(widget.token);
    if (mounted) {
      setState(() => _items = _items.map((x) => x.asRead()).toList());
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('All')),
              ButtonSegment(value: true, label: Text('Unread')),
            ],
            selected: {_unreadOnly},
            onSelectionChanged: (x) {
              _unreadOnly = x.first;
              _page = 1;
              _load();
            },
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _all,
            icon: const Icon(LucideIcons.checkCheck),
            label: const Text('Mark all read'),
          ),
        ],
      ),
      const SizedBox(height: 22),
      Expanded(
        child: Card(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: OutlinedButton(onPressed: _load, child: Text(_error!)),
                )
              : _items.isEmpty
              ? const Center(child: Text('No notifications yet.'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return ListTile(
                      onTap: () => _read(item),
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
                              ? FontWeight.w500
                              : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(item.message),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_relative(item.createdAtUtc)),
                          const SizedBox(width: 16),
                          if (!item.isRead)
                            const Icon(
                              Icons.circle,
                              size: 8,
                              color: Colors.blue,
                            ),
                          const SizedBox(width: 10),
                          const Icon(LucideIcons.chevronRight, size: 18),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: _page > 1
                ? () {
                    _page--;
                    _load();
                  }
                : null,
            icon: const Icon(LucideIcons.chevronLeft),
          ),
          Text('Page $_page'),
          IconButton(
            onPressed: _page * 20 < _total
                ? () {
                    _page++;
                    _load();
                  }
                : null,
            icon: const Icon(LucideIcons.chevronRight),
          ),
        ],
      ),
    ],
  );
  String _relative(DateTime value) {
    final d = DateTime.now().toUtc().difference(value);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}
