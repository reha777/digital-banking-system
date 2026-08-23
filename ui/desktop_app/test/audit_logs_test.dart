import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/features/admin_shell/admin_section.dart';
import 'package:desktop_app/src/features/admin_shell/widgets/admin_sidebar.dart';
import 'package:desktop_app/src/features/audit_logs/audit_log_models.dart';
import 'package:desktop_app/src/features/audit_logs/audit_log_service.dart';
import 'package:desktop_app/src/features/audit_logs/audit_logs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sidebar exposes functional Audit Logs section', (tester) async {
    AdminSection? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: AdminSidebar(
              userName: 'Admin',
              selectedSection: AdminSection.dashboard,
              onSectionSelected: (value) => selected = value,
              onLogout: () {},
              compact: false,
            ),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Audit Logs'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Audit Logs'), findsOneWidget);
    await tester.tap(find.text('Audit Logs'));
    expect(selected, AdminSection.auditLogs);
  });

  testWidgets('page renders filters, premium table and structured details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeAuditService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuditLogsPage(
            token: 'token',
            defaultPageSize: 20,
            dateFormatter: (value) => '22.08.2026 12:00',
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Customer Status Changed'), findsOneWidget);
    expect(find.text('Search audit logs'), findsOneWidget);
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('ACTION'), findsOneWidget);
    expect(find.text('TARGET'), findsOneWidget);
    expect(find.text('DESCRIPTION'), findsOneWidget);
    expect(find.text('Reason'), findsNothing);
    expect(find.textContaining('Showing 1 to 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('audit-view-1')));
    await tester.pumpAndSettle();
    expect(find.text('Audit Log Details'), findsOneWidget);
    expect(find.text('ACTOR & ACTION'), findsOneWidget);
    expect(find.text('TARGET'), findsWidgets);
    expect(find.text('DESCRIPTION'), findsWidgets);
    expect(find.text('CHANGES'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('REASON'), findsOneWidget);
    expect(find.text('Compliance review required.'), findsOneWidget);
    expect(find.text('TECHNICAL DETAILS'), findsOneWidget);
    expect(find.textContaining('corr-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters preserve behavior and modern dropdown selection', (
    tester,
  ) async {
    final service = FakeAuditService();
    await tester.pumpWidget(_page(service));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'customer');
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();
    expect(service.lastSearch, 'customer');

    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(MenuItemButton, 'Customer Status Changed'),
    );
    await tester.pumpAndSettle();
    expect(service.lastAction, 'CustomerStatusChanged');
  });

  testWidgets(
    'narrow viewport uses compact rows and dialog does not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_page(FakeAuditService()));
      await tester.pumpAndSettle();
      expect(find.text('TIME'), findsNothing);
      expect(find.text('Customer Status Changed'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('audit-view-1')));
      await tester.pumpAndSettle();
      expect(find.text('Audit Log Details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty and safe error states expose clear and retry actions', (
    tester,
  ) async {
    await tester.pumpWidget(_page(FakeAuditService(empty: true)));
    await tester.pumpAndSettle();
    expect(find.text('No audit activity'), findsOneWidget);
    expect(
      find.text('Administrative actions will appear here.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_page(FakeAuditService(fail: true)));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });
}

Widget _page(AuditLogService service) => MaterialApp(
  home: Scaffold(
    body: AuditLogsPage(
      token: 'token',
      defaultPageSize: 20,
      dateFormatter: (value) => '22.08.2026 12:00',
      service: service,
    ),
  ),
);

class FakeAuditService extends AuditLogService {
  FakeAuditService({this.empty = false, this.fail = false})
    : super(ApiClient());
  final bool empty, fail;
  String? lastSearch, lastAction;
  @override
  Future<AuditLogPageModel> getLogs({
    required String token,
    required int page,
    required int pageSize,
    String? search,
    String? action,
    String? entityType,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    lastSearch = search;
    lastAction = action;
    if (fail) throw Exception('sensitive technical failure');
    return AuditLogPageModel(
      items: empty
          ? []
          : [
              AuditLogEntry(
                id: '1',
                actorName: 'System Admin',
                actorRole: 'Admin',
                action: 'CustomerStatusChanged',
                actionDisplayName: 'Customer Status Changed',
                entityType: 'Customer',
                entityId: 'customer-1',
                description: 'Customer status changed from Active to Blocked.',
                reason: 'Compliance review required.',
                oldValue: 'Active',
                newValue: 'Blocked',
                correlationId: 'corr-1',
                createdAtUtc: DateTime.utc(2026, 8, 22, 12),
              ),
            ],
      page: 1,
      pageSize: 20,
      totalCount: empty ? 0 : 1,
    );
  }
}
