import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/api_client.dart';
import '../../widgets/app_pagination.dart';
import 'reference_data_service.dart';

class ReferenceDataPage extends StatefulWidget {
  const ReferenceDataPage({super.key, required this.token});
  final String token;
  @override
  State<ReferenceDataPage> createState() => _ReferenceDataPageState();
}

class _ReferenceDataPageState extends State<ReferenceDataPage>
    with SingleTickerProviderStateMixin {
  static const types = [
    'loan-purposes',
    'document-types',
    'transaction-categories',
  ];
  late final TabController tabs;
  late final ReferenceDataService service;
  final search = TextEditingController();
  Timer? _searchDebounce;
  bool? active;
  bool loading = true;
  Object? error;
  List<ReferenceItem> values = const [];
  int page = 1;
  int pageSize = 20;
  int totalCount = 0;
  int totalPages = 0;
  String get type => types[tabs.index];
  @override
  void initState() {
    super.initState();
    service = ReferenceDataService(ApiClient());
    tabs = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!tabs.indexIsChanging) {
          page = 1;
          _load();
        }
      });
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    tabs.dispose();
    search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      page = 1;
      _load();
    });
  }

  void _submitSearch(String _) {
    _searchDebounce?.cancel();
    page = 1;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await service.get(
        widget.token,
        type,
        search: search.text,
        active: active,
        page: page,
        pageSize: pageSize,
      );
      if (mounted) {
        setState(() {
          values = data.items;
          page = data.page;
          pageSize = data.pageSize;
          totalCount = data.totalCount;
          totalPages = data.totalPages;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _edit([ReferenceItem? existing]) async {
    final code = TextEditingController(text: existing?.code);
    final name = TextEditingController(text: existing?.name);
    final description = TextEditingController(text: existing?.description);
    final sort = TextEditingController(text: '${existing?.sortOrder ?? 10}');
    var enabled = existing?.isActive ?? true;
    final saved = await showDialog<ReferenceItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            existing == null ? 'Add reference value' : 'Edit reference value',
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'Code'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sort,
                  decoration: const InputDecoration(labelText: 'Sort order'),
                ),
                SwitchListTile(
                  value: enabled,
                  onChanged: (value) => update(() => enabled = value),
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: code.text.trim().isEmpty || name.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                      context,
                      ReferenceItem(
                        id: existing?.id ?? '',
                        code: code.text,
                        name: name.text,
                        description: description.text,
                        isActive: enabled,
                        sortOrder: int.tryParse(sort.text) ?? 0,
                      ),
                    ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != null) {
      await service.save(widget.token, type, saved, create: existing == null);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manage reusable banking configuration values.'),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Loan Purposes'),
                    Tab(text: 'Document Types'),
                    Tab(text: 'Transaction Categories'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                      controller: search,
                      onChanged: _onSearchChanged,
                      onSubmitted: _submitSearch,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LucideIcons.search),
                        hintText: 'Search code or name',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<bool?>(
                      initialValue: active,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(value: true, child: Text('Active')),
                        DropdownMenuItem(value: false, child: Text('Inactive')),
                      ],
                      onChanged: (value) {
                        active = value;
                        page = 1;
                        _load();
                      },
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
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(
                    child: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(LucideIcons.refreshCw),
                      label: const Text('Retry'),
                    ),
                  )
                : values.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.database, size: 42),
                        SizedBox(height: 12),
                        Text(
                          'No reference values found.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: Card(
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
                                        DataColumn(label: Text('Description')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Sort Order')),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows: values
                                          .map(
                                            (item) => DataRow(
                                              cells: [
                                                DataCell(Text(item.code)),
                                                DataCell(Text(item.name)),
                                                DataCell(
                                                  SizedBox(
                                                    width: 280,
                                                    child: Text(
                                                      item.description ?? '',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  _StatusPill(
                                                    active: item.isActive,
                                                  ),
                                                ),
                                                DataCell(
                                                  Text('${item.sortOrder}'),
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
                                                      IconButton(
                                                        tooltip: item.isActive
                                                            ? 'Deactivate'
                                                            : 'Activate',
                                                        onPressed: () => service
                                                            .save(
                                                              widget.token,
                                                              type,
                                                              ReferenceItem(
                                                                id: item.id,
                                                                code: item.code,
                                                                name: item.name,
                                                                description: item
                                                                    .description,
                                                                isActive: !item
                                                                    .isActive,
                                                                sortOrder: item
                                                                    .sortOrder,
                                                              ),
                                                            )
                                                            .then(
                                                              (_) => _load(),
                                                            ),
                                                        icon: Icon(
                                                          item.isActive
                                                              ? LucideIcons
                                                                    .circleOff
                                                              : LucideIcons
                                                                    .checkCircle,
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
                      const SizedBox(height: 12),
                      AppPagination(
                        currentPage: page,
                        totalPages: totalPages < 1 ? 1 : totalPages,
                        pageSize: pageSize,
                        shownCount: values.length,
                        totalCount: totalCount,
                        itemLabel: 'reference values',
                        onPageSelected: (value) {
                          page = value;
                          _load();
                        },
                        onPageSizeChanged: (value) {
                          page = 1;
                          pageSize = value;
                          _load();
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final color = active
        ? const Color(0xFF14804A)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          active ? 'Active' : 'Inactive',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
