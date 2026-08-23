import 'package:desktop_app/src/features/settings/admin_date_time_formatter.dart';
import 'package:desktop_app/src/features/settings/admin_settings_models.dart';
import 'package:desktop_app/src/features/settings/sections/format_settings_section.dart';
import 'package:desktop_app/src/features/settings/sections/general_settings_section.dart';
import 'package:desktop_app/src/features/settings/sections/session_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('date time formatter applies timezone date and 24 hour preferences', () {
    final formatter = AdminDateTimeFormatter(_preferences());
    expect(
      formatter.dateTime(DateTime.utc(2026, 1, 15, 23, 30)),
      '16.01.2026. 00:30',
    );
    expect(formatter.time(DateTime.utc(2026, 7, 15, 12)), '14:00');
  });

  test('date time formatter applies 12 hour and alternate date format', () {
    final formatter = AdminDateTimeFormatter(
      _preferences(time: '12h', date: 'MM/DD/YYYY', timezone: 'UTC'),
    );
    expect(
      formatter.dateTime(DateTime.utc(2026, 8, 22, 13, 5)),
      '08/22/2026 1:05 PM',
    );
  });

  testWidgets(
    'settings hides inert company week system timezone and caching fields',
    (tester) async {
      final controllers = List.generate(
        8,
        (index) => TextEditingController(
          text: index < 2
              ? 'Brand'
              : index == 6
              ? '30'
              : '5',
        ),
      );
      addTearDown(() {
        for (final value in controllers) {
          value.dispose();
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                GeneralSettingsSection(
                  controllers: controllers,
                  onChanged: () {},
                ),
                FormatSettingsSection(value: _preferences(), onChanged: (_) {}),
                SessionSettingsSection(
                  controllers: controllers,
                  itemsPerPage: 20,
                  enableDataCaching: true,
                  onItemsChanged: (_) {},
                  onCachingChanged: (_) {},
                  onChanged: () {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('System Name'), findsOneWidget);
      expect(find.text('System Short Name'), findsOneWidget);
      expect(find.text('Company Name'), findsNothing);
      expect(find.text('Timezone'), findsNothing);
      expect(find.text('First Day of Week'), findsNothing);
      expect(find.text('Enable Data Caching'), findsNothing);
    },
  );
}

AdminPreferences _preferences({
  String time = '24h',
  String date = 'DD.MM.YYYY',
  String timezone = 'Europe/Sarajevo',
}) => AdminPreferences(
  themeMode: 'system',
  sidebarStyle: 'expanded',
  dateFormat: date,
  timeFormat: time,
  firstDayOfWeek: 'monday',
  numberFormat: '1,234.56',
  defaultItemsPerPage: 20,
  timezone: timezone,
);
