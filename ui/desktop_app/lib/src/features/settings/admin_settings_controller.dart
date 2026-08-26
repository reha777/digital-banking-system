import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme_controller.dart';
import '../../core/app_error_message.dart';
import 'admin_settings_models.dart';
import 'admin_settings_service.dart';
import 'admin_formatters.dart';
import 'admin_date_time_formatter.dart';

class AdminSettingsController extends ChangeNotifier {
  AdminSettingsController(this.service, this.themeController);
  static const _cacheKey = 'admin_preferences';
  final AdminSettingsService service;
  final ThemeController themeController;
  AdminSettings? settings;
  bool loading = false;
  String? error;
  AdminPreferences get preferences =>
      settings?.preferences ??
      const AdminPreferences(
        themeMode: 'system',
        sidebarStyle: 'expanded',
        dateFormat: 'DD.MM.YYYY',
        timeFormat: '24h',
        firstDayOfWeek: 'monday',
        numberFormat: '1,234.56',
        defaultItemsPerPage: 10,
        timezone: 'Europe/Sarajevo',
      );

  Future<void> initializeCache() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    if (raw != null) {
      await _applyPreferences(
        AdminPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        notify: false,
      );
    }
  }

  Future<void> load(String token) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      settings = await service.get(token);
      await _applyPreferences(settings!.preferences);
    } catch (e) {
      error = AppErrorMessage.from(
        e,
        fallback: 'Settings could not be loaded.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> savePreferences(String token, AdminPreferences value) async {
    final saved = await service.savePreferences(token, value);
    settings = AdminSettings(
      system: settings!.system,
      preferences: saved,
      profile: settings!.profile,
    );
    await _applyPreferences(saved);
  }

  Future<void> _applyPreferences(
    AdminPreferences value, {
    bool notify = true,
  }) async {
    AdminFormatters.numberFormat = value.numberFormat;
    await (await SharedPreferences.getInstance()).setString(
      _cacheKey,
      jsonEncode(value.toJson()),
    );
    await themeController.setThemeMode(switch (value.themeMode) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    });
    if (notify) notifyListeners();
  }

  String formatDate(DateTime value) {
    return AdminDateTimeFormatter(preferences).date(value);
  }

  void replaceSettings(AdminSettings value) {
    settings = value;
    notifyListeners();
  }

  String formatDateTime(DateTime value) =>
      AdminDateTimeFormatter(preferences).dateTime(value);

  String formatTime(DateTime value) =>
      AdminDateTimeFormatter(preferences).time(value);

  String formatNumber(num value, {bool currency = false}) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts.first;
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      groups.insert(0, digits.substring((end - 3).clamp(0, end), end));
    }
    final european = preferences.numberFormat == '1.234,56';
    final result =
        '${groups.join(european ? '.' : ',')}${european ? ',' : '.'}${parts.last}';
    return currency ? '\$$result' : result;
  }
}
