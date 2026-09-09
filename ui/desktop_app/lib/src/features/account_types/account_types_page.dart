import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/api_client.dart';
import '../../widgets/app_page_states.dart';
import '../../widgets/app_status_badge.dart';
import 'account_type_service.dart';

String _errorMessage(Object error, String fallback) =>
    error is ApiException && error.message.trim().isNotEmpty
    ? error.message
    : fallback;

class AccountTypesPage extends StatefulWidget {
  const AccountTypesPage({super.key, required this.token, this.service});
  final String token;
  final AccountTypeService? service;
  @override
  State<AccountTypesPage> createState() => _AccountTypesPageState();
}

class _AccountTypesPageState extends State<AccountTypesPage> {
  late final AccountTypeService _service;
  final _search = TextEditingController();
  List<AccountTypeItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AccountTypeService(ApiClient());
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
        setState(() => _error = 'Account types could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit([AccountTypeItem? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AccountTypeDialog(
        item: item,
        onSubmit: (code, name) => item == null
            ? _service.create(widget.token, code, name)
            : _service.update(widget.token, item.id, name),
      ),
    );
    if (saved != true) return;
    await _load();
    _notify(item == null ? 'Account type created.' : 'Account type updated.');
  }

  Future<void> _toggle(AccountTypeItem item) async {
    if (item.isActive && !await _confirmDeactivation(item)) return;
    try {
      await _service.setActive(widget.token, item.id, !item.isActive);
      await _load();
      _notify(
        item.isActive ? 'Account type deactivated.' : 'Account type activated.',
      );
    } catch (e) {
      _notify(_errorMessage(e, 'Account type status could not be changed.'));
    }
  }

  Future<bool> _confirmDeactivation(AccountTypeItem item) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Deactivate account type?'),
          content: Text(
            'Existing ${item.name} accounts keep their type. '
            'It only becomes unavailable for new assignments.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final values = _items
        .where(
          (item) =>
              query.isEmpty ||
              item.code.toLowerCase().contains(query) ||
              item.name.toLowerCase().contains(query),
        )
        .toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage the account types customers can hold. '
              'Deactivated types stay visible on existing accounts.',
            ),
            const SizedBox(height: 14),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 340,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(LucideIcons.search),
                          hintText: 'Search code or name',
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: const Text('Refresh'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _edit(),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('Add Account Type'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const AppLoadingState()
                  : _error != null
                  ? AppErrorState(onRetry: _load, message: _error!)
                  : values.isEmpty
                  ? AppEmptyState(
                      icon: LucideIcons.database,
                      title: 'No account types found.',
                      message: query.isEmpty
                          ? 'Add an account type to make it available to customers.'
                          : 'No account type matches the current search.',
                      onReset: query.isEmpty
                          ? null
                          : () => setState(_search.clear),
                    )
                  : Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: DataTable(
                                  columnSpacing: 34,
                                  headingRowColor: WidgetStatePropertyAll(
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLow,
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Code')),
                                    DataColumn(label: Text('Name')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: values
                                      .map(
                                        (item) => DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                item.code,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(item.name)),
                                            DataCell(
                                              AppStatusBadge(
                                                status: item.isActive
                                                    ? 'Active'
                                                    : 'Inactive',
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                children: [
                                                  IconButton(
                                                    tooltip: 'Edit',
                                                    onPressed: () =>
                                                        _edit(item),
                                                    icon: const Icon(
                                                      LucideIcons.pencil,
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        _toggle(item),
                                                    child: Text(
                                                      item.isActive
                                                          ? 'Deactivate'
                                                          : 'Activate',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns its own controllers so they outlive the dialog's exit transition.
class _AccountTypeDialog extends StatefulWidget {
  const _AccountTypeDialog({required this.item, required this.onSubmit});
  final AccountTypeItem? item;
  final Future<void> Function(String code, String name) onSubmit;
  @override
  State<_AccountTypeDialog> createState() => _AccountTypeDialogState();
}

class _AccountTypeDialogState extends State<_AccountTypeDialog> {
  late final _code = TextEditingController(text: widget.item?.code);
  late final _name = TextEditingController(text: widget.item?.name);
  bool _busy = false;
  String? _error;

  bool get _isCreate => widget.item == null;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    final name = _name.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() => _error = 'Code and name are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(code, name);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorMessage(e, 'Account type could not be saved.');
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_isCreate ? 'Create account type' : 'Edit account type'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _code,
            readOnly: !_isCreate,
            enabled: !_busy,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: 'Code',
              helperText: _isCreate
                  ? 'Unique identifier, for example BUSINESS.'
                  : 'Code cannot be changed after creation.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            enabled: !_busy,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Name',
              helperText: 'Displayed to customers and administrators.',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_isCreate ? 'Create' : 'Save'),
      ),
    ],
  );
}
