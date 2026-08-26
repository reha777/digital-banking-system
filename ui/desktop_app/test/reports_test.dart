import 'package:desktop_app/src/features/admin_shell/admin_section.dart';
import 'package:desktop_app/src/features/admin_shell/widgets/admin_sidebar.dart';
import 'package:desktop_app/src/features/reports/report_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Reports is available from the admin sidebar', (tester) async {
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
      find.text('Reports'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Reports'));
    expect(selected, AdminSection.reports);
  });

  test('report job model supports active and completed states', () {
    final queued = ReportJobModel.fromJson({
      'id': '1',
      'type': 'TransactionReport',
      'status': 'Queued',
      'requestedBy': 'Admin',
      'requestedAtUtc': '2026-08-24T10:00:00Z',
      'downloadAvailable': false,
    });
    final completed = ReportJobModel.fromJson({
      'id': '2',
      'type': 'LoanPortfolioReport',
      'status': 'Completed',
      'requestedBy': 'Admin',
      'requestedAtUtc': '2026-08-24T10:00:00Z',
      'downloadAvailable': true,
    });
    expect(queued.active, isTrue);
    expect(completed.active, isFalse);
    expect(completed.downloadAvailable, isTrue);
  });
}
