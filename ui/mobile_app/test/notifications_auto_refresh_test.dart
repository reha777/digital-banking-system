import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/auth/auth_models.dart';
import 'package:mobile_app/src/features/auth/auth_session.dart';
import 'package:mobile_app/src/features/notifications/notification_model.dart';
import 'package:mobile_app/src/features/notifications/notification_service.dart';
import 'package:mobile_app/src/features/notifications/notifications_page.dart';

/// Professor item 13: the notifications list must refresh itself while it is
/// open, without pull-to-refresh, reopening the page or restarting the app.
void main() {
  const interval = Duration(milliseconds: 60);

  testWidgets('a new notification appears without any manual refresh', (
    tester,
  ) async {
    final service = _FakeNotificationService()
      ..notifications = [_notification('a', 'Notification A')];
    await _pump(tester, service);

    expect(find.text('Notification A'), findsOneWidget);
    expect(find.text('Notification C'), findsNothing);
    expect(service.listCalls, 1);

    // The backend receives a newer notification while the page stays open.
    service.notifications = [
      _notification('c', 'Notification C'),
      _notification('a', 'Notification A'),
    ];
    await tester.pump(interval);
    await tester.pump();

    expect(find.text('Notification C'), findsOneWidget);
    expect(find.text('Notification A'), findsOneWidget);
    expect(service.listCalls, greaterThan(1));
    // Newest first, as before.
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(
      texts.indexOf('Notification C'),
      lessThan(texts.indexOf('Notification A')),
    );

    await _settle(tester);
  });

  testWidgets('polling stops when the page is disposed', (tester) async {
    final service = _FakeNotificationService()
      ..notifications = [_notification('a', 'Notification A')];
    await _pump(tester, service);
    final callsWhileOpen = service.listCalls;

    // Leave the page.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pump();
    await tester.pump(interval * 4);

    expect(service.listCalls, callsWhileOpen);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed background poll keeps the current list', (
    tester,
  ) async {
    final service = _FakeNotificationService()
      ..notifications = [_notification('a', 'Notification A')];
    await _pump(tester, service);
    expect(find.text('Notification A'), findsOneWidget);

    service.failNextList = true;
    await tester.pump(interval);
    await tester.pump();

    // No crash, no error screen, no emptied list.
    expect(find.text('Notification A'), findsOneWidget);
    expect(find.text('Notifications could not be loaded.'), findsNothing);
    expect(tester.takeException(), isNull);

    // The next cycle recovers.
    service.notifications = [
      _notification('c', 'Notification C'),
      _notification('a', 'Notification A'),
    ];
    await tester.pump(interval);
    await tester.pump();
    expect(find.text('Notification C'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('marking read survives the next poll and is not resurrected', (
    tester,
  ) async {
    final service = _FakeNotificationService()
      ..notifications = [_notification('a', 'Notification A', isRead: false)];
    await _pump(tester, service);

    expect(find.text('Mark all read'), findsOneWidget);

    await tester.tap(find.text('Notification A'));
    await tester.pump();

    // The list item is read immediately, so the unread action disappears.
    expect(service.markedRead, ['a']);
    expect(find.text('Mark all read'), findsNothing);

    // The backend now agrees, and the poll keeps it read.
    service.notifications = [
      _notification('a', 'Notification A', isRead: true),
    ];
    await tester.pump(interval);
    await tester.pump();
    expect(find.text('Mark all read'), findsNothing);

    await _settle(tester);
  });

  testWidgets('a poll in flight before mark-as-read cannot revert the state', (
    tester,
  ) async {
    final service = _FakeNotificationService()
      ..notifications = [_notification('a', 'Notification A', isRead: false)];
    await _pump(tester, service);

    // Hold the next list response open, then mark as read while it is pending.
    service.holdList = true;
    await tester.pump(interval);
    await tester.tap(find.text('Notification A'));
    await tester.pump();
    expect(find.text('Mark all read'), findsNothing);

    // The stale response, still carrying isRead:false, now lands.
    service.releaseList();
    await tester.pump();
    await tester.pump();

    expect(find.text('Mark all read'), findsNothing);

    await _settle(tester);
  });

  testWidgets('pull to refresh still works and starts no second timer', (
    tester,
  ) async {
    final service = _FakeNotificationService()
      ..notifications = [_notification('a', 'Notification A')];
    await _pump(tester, service);

    service.notifications = [
      _notification('b', 'Notification B'),
      _notification('a', 'Notification A'),
    ];
    await tester.fling(find.text('Notification A'), const Offset(0, 320), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Notification B'), findsOneWidget);
    // One announcements fetch on load plus one for the manual refresh: the
    // manual path did not install another recurring poll.
    expect(service.announcementCalls, 2);

    await _settle(tester);
  });

  testWidgets('announcements stay a separate list with no read state', (
    tester,
  ) async {
    final service = _FakeNotificationService()
      ..notifications = [_notification('a', 'Notification A', isRead: true)]
      ..announcements = [
        SystemAnnouncement.fromJson({
          'id': 'announcement-1',
          'title': 'Scheduled maintenance',
          'message': 'Service window.',
          // Zone-less UTC, exactly what the API sends.
          'publishAtUtc': '2026-09-09T13:52:00',
        }),
      ];
    await _pump(tester, service);

    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();

    expect(find.text('Scheduled maintenance'), findsOneWidget);
    expect(find.text('Notification A'), findsNothing);
    // Announcements carry no read/unread state of their own.
    expect(find.text('Mark all read'), findsNothing);

    // Background polling refreshes notifications without touching this tab.
    service.notifications = [
      _notification('c', 'Notification C', isRead: true),
      _notification('a', 'Notification A', isRead: true),
    ];
    await tester.pump(interval);
    await tester.pump();
    expect(find.text('Scheduled maintenance'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _settle(tester);
  });

  test('notification timestamps parse zone-less API values as UTC', () {
    final value = AppNotification.fromJson({
      'id': 'a',
      'type': 'TransactionApproved',
      'title': 'Title',
      'message': 'Message',
      'isRead': false,
      // SQL datetime2 serializes UTC without a trailing Z.
      'createdAtUtc': '2026-09-09T13:52:00',
    });

    expect(value.createdAtUtc.isUtc, isTrue);
    expect(value.createdAtUtc, DateTime.utc(2026, 9, 9, 13, 52));
    // An explicit designator still describes the same instant.
    expect(
      AppNotification.fromJson({
        'id': 'a',
        'type': 'T',
        'title': 'T',
        'message': 'M',
        'isRead': false,
        'createdAtUtc': '2026-09-09T15:52:00+02:00',
      }).createdAtUtc,
      DateTime.utc(2026, 9, 9, 13, 52),
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeNotificationService service,
) async {
  final session = AuthSession(ApiClient())
    ..token = 'customer-token'
    ..user = const AuthUser(
      id: 'customer-1',
      firstName: 'Test',
      lastName: 'Customer',
      email: 'customer@test.local',
      role: 'Customer',
    );
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationsPage(
        session: session,
        service: service,
        pollInterval: const Duration(milliseconds: 60),
      ),
    ),
  );
  await tester.pump();
}

/// Leaves no pending timer behind when the test ends.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
  await tester.pump();
}

AppNotification _notification(String id, String title, {bool isRead = false}) =>
    AppNotification(
      id: id,
      type: 'TransactionApproved',
      title: title,
      message: 'Message for $title',
      isRead: isRead,
      createdAtUtc: DateTime.now().toUtc(),
    );

class _FakeNotificationService implements NotificationService {
  List<AppNotification> notifications = const [];
  List<SystemAnnouncement> announcements = const [];
  List<String> markedRead = [];
  int listCalls = 0;
  int announcementCalls = 0;
  bool failNextList = false;
  bool holdList = false;
  Completer<void>? _gate;

  void releaseList() {
    _gate?.complete();
    _gate = null;
  }

  @override
  Future<NotificationPageResult> getNotifications({
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
  }) async {
    listCalls++;
    if (holdList) {
      holdList = false;
      _gate = Completer<void>();
      await _gate!.future;
    }
    if (failNextList) {
      failNextList = false;
      throw ApiException('offline', 503);
    }
    return NotificationPageResult(
      items: List<AppNotification>.from(notifications),
      totalCount: notifications.length,
    );
  }

  @override
  Future<List<SystemAnnouncement>> getAnnouncements() async {
    announcementCalls++;
    return List<SystemAnnouncement>.from(announcements);
  }

  @override
  Future<int> unreadCount() async =>
      notifications.where((item) => !item.isRead).length;

  @override
  Future<void> markRead(String id) async {
    markedRead.add(id);
  }

  @override
  Future<void> markAllRead() async {
    markedRead.addAll(notifications.where((x) => !x.isRead).map((x) => x.id));
  }
}
