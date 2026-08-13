import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../widgets/app_page_header.dart';
import '../../../widgets/app_page_states.dart';
import '../admin_settings_controller.dart';
import '../admin_settings_models.dart';
import '../sections/appearance_settings_section.dart';
import '../sections/format_settings_section.dart';
import '../sections/general_settings_section.dart';
import '../sections/profile_settings_section.dart';
import '../sections/security_settings_section.dart';
import '../sections/session_settings_section.dart';
import '../widgets/settings_navigation.dart';
import '../widgets/settings_save_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.token,
    required this.controller,
    required this.onProfileUpdated,
    required this.initialSection,
    required this.headerAction,
  });
  final String token;
  final AdminSettingsController controller;
  final ValueChanged<AdminProfile> onProfileUpdated;
  final SettingsSection initialSection;
  final Widget headerAction;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsSection _section;
  List<TextEditingController> _general = [];
  List<TextEditingController> _profile = [];
  List<TextEditingController> _security = [];
  AdminPreferences? _preferences;
  bool _dirty = false;
  bool _saving = false;
  bool _enableDataCaching = true;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    widget.controller.addListener(_loaded);
    if (widget.controller.settings == null) {
      widget.controller.load(widget.token);
    }
    _loaded();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() => _section = widget.initialSection);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_loaded);
    for (final controller in [..._general, ..._profile, ..._security]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loaded() {
    final data = widget.controller.settings;
    if (!mounted || data == null || _general.isNotEmpty) return;
    setState(() {
      _general = <String>[
        data.system.systemName,
        data.system.systemShortName,
        data.system.companyName,
        data.system.companyEmail,
        data.system.companyPhone,
        data.system.timezone,
        '${data.system.sessionTimeoutMinutes}',
        '${data.system.autoLogoutWarningMinutes}',
      ].map((value) => TextEditingController(text: value)).toList();
      _profile = <String>[
        data.profile.firstName,
        data.profile.lastName,
        data.profile.email,
        data.profile.phoneNumber,
      ].map((value) => TextEditingController(text: value)).toList();
      _security = List.generate(3, (_) => TextEditingController());
      _preferences = data.preferences;
      _enableDataCaching = data.system.enableDataCaching;
    });
  }

  Future<void> _select(SettingsSection value) async {
    if (_dirty && !await _confirmDiscard()) return;
    setState(() {
      _section = value;
      _dirty = false;
    });
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text('Changes in this section have not been saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      switch (_section) {
        case SettingsSection.general:
          await _saveGeneral();
        case SettingsSection.profile:
          await _saveProfile();
        case SettingsSection.security:
          return;
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveGeneral() async {
    final saved = await widget.controller.service.saveSystem(
      widget.token,
      SystemSettings(
        systemName: _general[0].text,
        systemShortName: _general[1].text,
        companyName: _general[2].text,
        companyEmail: _general[3].text,
        companyPhone: _general[4].text,
        timezone: _general[5].text,
        sessionTimeoutMinutes: int.parse(_general[6].text),
        autoLogoutWarningMinutes: int.parse(_general[7].text),
        enableDataCaching: _enableDataCaching,
        updatedAtUtc: widget.controller.settings!.system.updatedAtUtc,
      ),
    );
    await widget.controller.savePreferences(widget.token, _preferences!);
    widget.controller.settings = AdminSettings(
      system: saved,
      preferences: _preferences!,
      profile: widget.controller.settings!.profile,
    );
  }

  Future<void> _saveProfile() async {
    final saved = await widget.controller.service.saveProfile(
      widget.token,
      AdminProfile(
        firstName: _profile[0].text,
        lastName: _profile[1].text,
        email: _profile[2].text,
        phoneNumber: _profile[3].text,
      ),
    );
    await widget.controller.savePreferences(widget.token, _preferences!);
    widget.controller.settings = AdminSettings(
      system: widget.controller.settings!.system,
      preferences: widget.controller.settings!.preferences,
      profile: saved,
    );
    widget.onProfileUpdated(saved);
  }

  Future<void> _savePassword() async {
    setState(() => _saving = true);
    try {
      await widget.controller.service.changePassword(
        widget.token,
        _security[0].text,
        _security[1].text,
      );
      for (final controller in _security) {
        controller.clear();
      }
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.loading && widget.controller.settings == null) {
      return const AppLoadingState();
    }
    if (widget.controller.settings == null) {
      return AppErrorState(
        message: widget.controller.error ?? 'Settings could not be loaded.',
        onRetry: () => widget.controller.load(widget.token),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPageHeader(
          icon: LucideIcons.settings,
          title: 'Settings',
          subtitle: 'Manage your system preferences and configurations.',
          action: widget.headerAction,
        ),
        const SizedBox(height: 20),
        Expanded(child: LayoutBuilder(builder: _layout)),
      ],
    );
  }

  Widget _layout(BuildContext context, BoxConstraints constraints) {
    final navigation = SettingsNavigation(value: _section, onChanged: _select);
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(.008, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(_section), child: _content()),
    );
    if (constraints.maxWidth >= 850) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 245, child: navigation),
          const SizedBox(width: 18),
          Expanded(child: content),
        ],
      );
    }
    return Column(
      children: [
        SettingsNavigation(value: _section, onChanged: _select, compact: true),
        const SizedBox(height: 12),
        Expanded(child: content),
      ],
    );
  }

  Widget _content() => switch (_section) {
    SettingsSection.general => _generalContent(),
    SettingsSection.profile => _profileContent(),
    SettingsSection.security => _securityContent(),
  };

  Widget _generalContent() => Column(
    children: [
      _sectionHeader(
        'General Settings',
        'Configure basic information about your banking system.',
        save: true,
      ),
      const SizedBox(height: 14),
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            children: [
              GeneralSettingsSection(
                controllers: _general,
                onChanged: _markDirty,
              ),
              const SizedBox(height: 16),
              AppearanceSettingsSection(
                value: _preferences!,
                onChanged: (value) => setState(() {
                  _preferences = value;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 16),
              FormatSettingsSection(
                value: _preferences!,
                onChanged: (value) => setState(() {
                  _preferences = value;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 16),
              SessionSettingsSection(
                controllers: _general,
                itemsPerPage: _preferences!.defaultItemsPerPage,
                enableDataCaching: _enableDataCaching,
                onItemsChanged: (value) => setState(() {
                  _preferences = _copyPreferences(itemsPerPage: value);
                  _dirty = true;
                }),
                onCachingChanged: (value) => setState(() {
                  _enableDataCaching = value;
                  _dirty = true;
                }),
                onChanged: _markDirty,
              ),
              const SizedBox(height: 16),
              _footerInfo(),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _profileContent() => Column(
    children: [
      _sectionHeader(
        'Profile',
        'Manage your administrator profile.',
        save: true,
      ),
      const SizedBox(height: 14),
      Expanded(
        child: SingleChildScrollView(
          child: ProfileSettingsSection(
            controllers: _profile,
            preferences: _preferences!,
            onPreferencesChanged: (value) => setState(() {
              _preferences = value;
              _dirty = true;
            }),
            onChanged: _markDirty,
          ),
        ),
      ),
    ],
  );

  Widget _securityContent() => Column(
    children: [
      _sectionHeader('Security', 'Manage your account password.'),
      const SizedBox(height: 14),
      Expanded(
        child: SingleChildScrollView(
          child: SecuritySettingsSection(
            controllers: _security,
            saving: _saving,
            onSubmit: _savePassword,
            onChanged: _markDirty,
          ),
        ),
      ),
    ],
  );

  Widget _sectionHeader(String title, String subtitle, {bool save = false}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          );
          if (!save) return heading;
          final action = SettingsSaveBar(
            dirty: _dirty,
            saving: _saving,
            onSave: _save,
          );
          if (constraints.maxWidth >= 620) {
            return Row(
              children: [
                Expanded(child: heading),
                const SizedBox(width: 20),
                action,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: action),
            ],
          );
        },
      );

  Widget _footerInfo() {
    final updated = widget.controller.settings!.system.updatedAtUtc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Text('Last Updated', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 18),
            Text(
              updated == null
                  ? 'Not available'
                  : widget.controller.formatDate(updated),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  void _markDirty() => setState(() => _dirty = true);

  AdminPreferences _copyPreferences({required int itemsPerPage}) =>
      AdminPreferences(
        themeMode: _preferences!.themeMode,
        sidebarStyle: _preferences!.sidebarStyle,
        dateFormat: _preferences!.dateFormat,
        timeFormat: _preferences!.timeFormat,
        firstDayOfWeek: _preferences!.firstDayOfWeek,
        numberFormat: _preferences!.numberFormat,
        defaultItemsPerPage: itemsPerPage,
        timezone: _preferences!.timezone,
      );
}
