import 'dart:convert';
import 'dart:typed_data';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/core/document_print_result.dart';
import 'package:desktop_app/src/features/reports/report_models.dart';
import 'package:desktop_app/src/features/reports/report_service.dart';
import 'package:desktop_app/src/features/reports/reports_page.dart';
import 'package:desktop_app/src/features/settings/admin_date_time_formatter.dart';
import 'package:desktop_app/src/features/settings/admin_settings_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Professor item 14: Reports must offer Print next to Download, Recent reports
/// must have a working filter, and the date must use the shared user-facing
/// formatter instead of a sliced DateTime string.
void main() {
  testWidgets('both report types offer Download and a working Print', (
    tester,
  ) async {
    final printer = _RecordingPrinter();
    await _pumpReports(tester, printer: printer);

    expect(find.text('Transaction Report'), findsWidgets);
    expect(find.text('Loan Portfolio Report'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Download'), findsNWidgets(2));
    expect(find.widgetWithText(TextButton, 'Print'), findsNWidgets(2));

    // Print the first report.
    await tester.tap(find.widgetWithText(TextButton, 'Print').first);
    await tester.pumpAndSettle();
    expect(printer.calls, 1);
    expect(printer.lastFileName, 'transaction-report.pdf');
    expect(find.text('Report sent to the printer.'), findsOneWidget);
    await _settleSnackBar(tester);

    // Print the second report type as well.
    await tester.tap(find.widgetWithText(TextButton, 'Print').last);
    await tester.pumpAndSettle();
    expect(printer.calls, 2);
    expect(printer.lastFileName, 'loan-portfolio-report.pdf');
    await _settleSnackBar(tester);
  });

  testWidgets('an unavailable printer is reported, never thrown', (
    tester,
  ) async {
    await _pumpReports(
      tester,
      printer: _RecordingPrinter(outcome: PrintOutcome.unavailable),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Print').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Printing is not available on this system. Use Download instead.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _settleSnackBar(tester);
  });

  testWidgets('a print failure surfaces a controlled message', (tester) async {
    await _pumpReports(tester, printer: _RecordingPrinter(throws: true));

    await tester.tap(find.widgetWithText(TextButton, 'Print').first);
    await tester.pumpAndSettle();

    expect(find.text('Report could not be printed.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _settleSnackBar(tester);
  });

  testWidgets('Recent reports can be filtered by type and cleared', (
    tester,
  ) async {
    await _pumpReports(tester);

    expect(find.text('Transaction Report'), findsWidgets);
    expect(find.text('Loan Portfolio Report'), findsWidgets);

    await _selectFilter(tester, 'Loan Portfolio Report');
    expect(find.widgetWithText(TextButton, 'Download'), findsOneWidget);
    expect(find.text('Loan Portfolio Report'), findsWidgets);
    // The transaction row is filtered out of the table.
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Transaction Report'),
      ),
      findsNothing,
    );

    await _selectFilter(tester, 'All report types');
    expect(find.widgetWithText(TextButton, 'Download'), findsNWidgets(2));
  });

  testWidgets('a filter with no matches shows an empty state, not an error', (
    tester,
  ) async {
    await _pumpReports(tester, jobs: [_job('1', 'transaction-report.pdf')]);

    await _selectFilter(tester, 'Loan Portfolio Report');

    expect(find.text('No matching reports'), findsOneWidget);
    expect(find.text('No reports match your filters.'), findsOneWidget);
    expect(find.textContaining('could not'), findsNothing);

    // Clearing brings the list back.
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Download'), findsOneWidget);
  });

  testWidgets('the requested date uses the shared DD.MM.YYYY HH:mm formatter', (
    tester,
  ) async {
    await _pumpReports(tester);

    // 14:35 UTC rendered in the admin's configured zone (Europe/Sarajevo, +02).
    expect(find.text('09.09.2026. 16:35'), findsWidgets);
    expect(find.textContaining('2026-09-09 '), findsNothing);
    expect(find.textContaining('T14:35'), findsNothing);
  });

  testWidgets('a cancelled print dialog is reported as cancelled', (
    tester,
  ) async {
    await _pumpReports(
      tester,
      printer: _RecordingPrinter(outcome: PrintOutcome.cancelled),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Print').first);
    await tester.pumpAndSettle();

    // Dismissing the dialog is a normal outcome, not "unavailable".
    expect(find.text('Printing was cancelled.'), findsOneWidget);
    expect(
      find.text(
        'Printing is not available on this system. Use Download instead.',
      ),
      findsNothing,
    );
    await _settleSnackBar(tester);
  });

  test('report type keys are stable across numeric and string enum forms', () {
    expect(_job('1', 'a.pdf').typeKey, 'transactions');
    expect(_job('2', 'b.pdf').typeKey, 'loans');
    expect(_job('TransactionReport', 'c.pdf').typeKey, 'transactions');
    expect(_job('LoanPortfolioReport', 'd.pdf').typeKey, 'loans');
  });
}

Future<void> _selectFilter(WidgetTester tester, String label) async {
  await tester.tap(find.text('Filter by type'));
  await tester.pumpAndSettle();
  // Scope to the open menu so a matching table cell cannot be tapped instead.
  await tester.tap(find.widgetWithText(MenuItemButton, label));
  await tester.pumpAndSettle();
}

Future<void> _settleSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> _pumpReports(
  WidgetTester tester, {
  _RecordingPrinter? printer,
  List<ReportJobModel>? jobs,
}) async {
  tester.view.physicalSize = const Size(1500, 950);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final items =
      jobs ??
      [
        _job('1', 'transaction-report.pdf'),
        _job('2', 'loan-portfolio-report.pdf'),
      ];
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/download')) {
      return http.Response.bytes([1, 2, 3], 200);
    }
    return http.Response(
      jsonEncode({
        'items': items.map(_toJson).toList(),
        'page': 1,
        'pageSize': 20,
        'totalCount': items.length,
      }),
      200,
    );
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReportsPage(
          token: 'token',
          dateFormatter: const AdminDateTimeFormatter(_preferences).dateTime,
          printer: printer?.call,
          service: ReportService(ApiClient(httpClient: client)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _toJson(ReportJobModel job) => {
  'id': job.id,
  'type': job.type,
  'status': job.status,
  'requestedBy': job.requestedBy,
  'requestedAtUtc': '2026-09-09T14:35:00Z',
  'fileName': job.fileName,
  'downloadAvailable': job.downloadAvailable,
};

ReportJobModel _job(String type, String fileName) => ReportJobModel(
  id: 'job-$type',
  type: type,
  status: 'Completed',
  requestedBy: 'Admin User',
  requestedAtUtc: DateTime.utc(2026, 9, 9, 14, 35),
  fileName: fileName,
  downloadAvailable: true,
);

class _RecordingPrinter {
  _RecordingPrinter({this.outcome = PrintOutcome.printed, this.throws = false});

  final PrintOutcome outcome;
  final bool throws;
  int calls = 0;
  String? lastFileName;

  Future<PrintOutcome> call({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    calls++;
    lastFileName = fileName;
    if (throws) throw StateError('no printer');
    return outcome;
  }
}

const _preferences = AdminPreferences(
  themeMode: 'light',
  sidebarStyle: 'expanded',
  dateFormat: 'DD.MM.YYYY',
  timeFormat: '24h',
  firstDayOfWeek: 'monday',
  numberFormat: '1,234.56',
  defaultItemsPerPage: 20,
  timezone: 'Europe/Sarajevo',
);
