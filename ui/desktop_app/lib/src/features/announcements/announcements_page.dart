import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/api_client.dart';
import 'announcement_service.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key, required this.token, this.dateFormatter});
  final String token;
  final String Function(DateTime)? dateFormatter;
  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  late final AnnouncementService _service;
  List<Announcement> _items = const [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _service = AnnouncementService(ApiClient());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.getAll(widget.token);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Announcements could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Renders a UTC instant for the admin. The injected formatter shifts UTC into
  /// the admin's configured timezone itself, so it must receive the UTC value —
  /// converting first would hand it a local wall clock and shift it twice.
  String _date(DateTime value) =>
      widget.dateFormatter?.call(value.toUtc()) ?? _localDateTime(value);

  /// `DD.MM.YYYY HH:mm` in device local time, for values the admin picked
  /// locally and for the formatter-less fallback.
  static String _localDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _edit([Announcement? existing]) async {
    final title = TextEditingController(text: existing?.title);
    final message = TextEditingController(text: existing?.message);
    var publishAt = existing?.publishAtUtc.toLocal() ?? DateTime.now();
    var busy = false;
    String? validation;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            existing == null ? 'Create announcement' : 'Edit announcement',
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: title,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: message,
                  maxLength: 2000,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.calendarClock),
                  label: Text('Publish: ${_localDateTime(publishAt)}'),
                  onPressed: busy
                      ? null
                      : () async {
                          final day = await showDatePicker(
                            context: context,
                            initialDate: publishAt,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (day == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(publishAt),
                          );
                          if (time != null) {
                            update(
                              () => publishAt = DateTime(
                                day.year,
                                day.month,
                                day.day,
                                time.hour,
                                time.minute,
                              ),
                            );
                          }
                        },
                ),
                if (validation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      validation!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty ||
                          message.text.trim().isEmpty) {
                        update(
                          () => validation = 'Title and message are required.',
                        );
                        return;
                      }
                      update(() {
                        busy = true;
                        validation = null;
                      });
                      try {
                        await _service.save(
                          widget.token,
                          id: existing?.id,
                          title: title.text.trim(),
                          message: message.text.trim(),
                          publishAtUtc: publishAt.toUtc(),
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        await _load();
                      } on ApiException catch (e) {
                        update(() {
                          busy = false;
                          validation = e.message;
                        });
                      }
                    },
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    message.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Create and schedule important system messages for all customers.',
              ),
            ),
            FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Create Announcement'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _loading
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
              ? const Center(child: Text('No announcements yet.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final x = _items[i];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            child: Icon(
                              x.isPublished
                                  ? LucideIcons.megaphone
                                  : LucideIcons.clock,
                            ),
                          ),
                          title: Text(
                            x.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              x.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(
                                  x.isPublished ? 'Published' : 'Scheduled',
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(_date(x.publishAtUtc)),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _edit(x),
                                tooltip: 'Edit',
                                icon: const Icon(LucideIcons.pencil),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}
