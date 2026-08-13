import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/api_client.dart';
import '../../../core/document_opener.dart';
import '../../../widgets/admin_modal.dart';
import '../../../widgets/app_page_header.dart';
import '../../../widgets/app_page_states.dart';
import '../admin_card_request_models.dart';
import '../admin_card_request_service.dart';
import '../widgets/card_document_preview.dart';
import '../widgets/card_request_details_dialog.dart';
import '../widgets/card_request_filters.dart';
import '../widgets/card_request_summary_cards.dart';
import '../widgets/card_requests_table.dart';

class CardRequestsPage extends StatefulWidget {
  const CardRequestsPage({
    super.key,
    required this.token,
    required this.defaultPageSize,
    required this.dateFormatter,
    this.showHeader = true,
  });
  final String token;
  final int defaultPageSize;
  final String Function(DateTime) dateFormatter;
  final bool showHeader;
  @override
  State<CardRequestsPage> createState() => _CardRequestsPageState();
}

class _CardRequestsPageState extends State<CardRequestsPage> {
  final _searchController = TextEditingController();
  final _tableController = ScrollController();
  late final AdminCardRequestService _service;
  late Future<_CardRequestsData> _future;
  Timer? _debounce;
  int _page = 1;
  late int _pageSize;
  int? _status;
  @override
  void initState() {
    super.initState();
    _pageSize = widget.defaultPageSize;
    _service = AdminCardRequestService(ApiClient());
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tableController.dispose();
    super.dispose();
  }

  Future<_CardRequestsData> _load() async {
    final values = await Future.wait<Object>([
      _service.getRequests(
        token: widget.token,
        page: _page,
        pageSize: _pageSize,
        search: _searchController.text,
        status: _status,
      ),
      _service.getSummary(
        token: widget.token,
        search: _searchController.text,
        status: _status,
      ),
    ]);
    return _CardRequestsData(
      page: values[0] as AdminCardRequestPage,
      summary: values[1] as AdminCardRequestSummary,
    );
  }

  void _refresh() {
    if (mounted) setState(() => _future = _load());
  }

  void _fromFirstPage() {
    _page = 1;
    if (_tableController.hasClients) _tableController.jumpTo(0);
    _refresh();
  }

  void _search(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _fromFirstPage);
  }

  void _reset() {
    _debounce?.cancel();
    _searchController.clear();
    _status = null;
    _fromFirstPage();
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  Future<String?> _reviewNote(
    AdminCardRequest request,
    String title,
    String action, {
    Color? color,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AdminModal(
        title: title,
        primaryLabel: action,
        primaryColor: color,
        onPrimary: () => Navigator.pop(dialogContext, controller.text.trim()),
        children: [
          Text(
            '${request.customerName} requested a ${request.currency} account and card.',
          ),
          const SizedBox(height: 14),
          AdminModalField(
            controller: controller,
            label: 'Admin note',
            icon: LucideIcons.fileText,
          ),
        ],
      ),
    );
  }

  Future<bool> _approve(AdminCardRequest request) async {
    final note = await _reviewNote(request, 'Approve card request', 'Approve');
    if (note == null) return false;
    try {
      await _service.approve(
        token: widget.token,
        id: request.id,
        adminNote: note,
      );
      if (mounted) {
        _message('Card request approved.');
        _refresh();
      }
      return true;
    } on ApiException catch (e) {
      if (mounted) _message(e.message);
      return false;
    }
  }

  Future<bool> _reject(AdminCardRequest request) async {
    final note = await _reviewNote(
      request,
      'Reject card request',
      'Reject',
      color: const Color(0xFFDC2626),
    );
    if (note == null) return false;
    try {
      await _service.reject(
        token: widget.token,
        id: request.id,
        adminNote: note,
      );
      if (mounted) {
        _message('Card request rejected.');
        _refresh();
      }
      return true;
    } on ApiException catch (e) {
      if (mounted) _message(e.message);
      return false;
    }
  }

  Future<bool> _requestDocuments(AdminCardRequest request, String note) async {
    try {
      await _service.requestDocuments(
        token: widget.token,
        id: request.id,
        adminNote: note,
      );
      if (mounted) {
        _message('Document request sent to customer.');
        _refresh();
      }
      return true;
    } on ApiException catch (e) {
      if (mounted) _message(e.message);
      return false;
    }
  }

  Future<Uint8List> _selectDocument(
    AdminCardRequest request,
    AdminCardRequestDocument document,
  ) async {
    final bytes = Uint8List.fromList(
      await _service.downloadDocument(
        token: widget.token,
        requestId: request.id,
        documentId: document.id,
      ),
    );
    final opened = await openDocumentBytes(
      bytes: bytes,
      fileName: document.fileName,
      contentType: cardDocumentContentType(document),
    );
    if (!opened && mounted) {
      _message('Document loaded below. Browser opening is available on web.');
    }
    return bytes;
  }

  Future<void> _details(AdminCardRequest request) => showDialog<void>(
    context: context,
    builder: (_) => CardRequestDetailsDialog(
      request: request,
      onApprove: () => _approve(request),
      onReject: () => _reject(request),
      onRequestDocuments: (note) => _requestDocuments(request, note),
      onSelectDocument: (document) => _selectDocument(request, document),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.showHeader) ...[
        const AppPageHeader(
          icon: LucideIcons.creditCard,
          title: 'Card Requests',
          subtitle: 'Review account and card requests from mobile customers.',
        ),
        const SizedBox(height: 22),
      ],
      CardRequestFilters(
        searchController: _searchController,
        status: _status,
        onSearchChanged: _search,
        onStatusChanged: (value) {
          _status = value;
          _fromFirstPage();
        },
        onRefresh: _refresh,
        onReset: _reset,
      ),
      const SizedBox(height: 18),
      Expanded(
        child: FutureBuilder<_CardRequestsData>(
          future: _future,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const AppLoadingState();
            }
            if (snapshot.hasError) {
              return AppErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }
            final data = snapshot.requireData;
            if (data.page.items.isEmpty) {
              return AppEmptyState(
                icon: LucideIcons.creditCard,
                title: 'No card requests found',
                message: 'Try changing the search or status filter.',
                onReset: _reset,
              );
            }
            return Column(
              children: [
                if (snapshot.connectionState != ConnectionState.done)
                  const LinearProgressIndicator(minHeight: 2),
                CardRequestSummaryCards(summary: data.summary),
                const SizedBox(height: 16),
                Expanded(
                  child: CardRequestsTable(
                    dateFormatter: widget.dateFormatter,
                    page: data.page,
                    pageSize: _pageSize,
                    controller: _tableController,
                    onDetails: _details,
                    onPageSelected: (value) {
                      _page = value;
                      _refresh();
                    },
                    onPageSizeChanged: (value) {
                      _pageSize = value;
                      _fromFirstPage();
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class _CardRequestsData {
  const _CardRequestsData({required this.page, required this.summary});
  final AdminCardRequestPage page;
  final AdminCardRequestSummary summary;
}
