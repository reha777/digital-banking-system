import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/app_error_message.dart';

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
    this.showHeader = true,
  });
  final String token;
  final AdminSettingsController controller;
  final ValueChanged<AdminProfile> onProfileUpdated;
  final SettingsSection initialSection;
  final Widget headerAction;
  final bool showHeader;
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
  bool _photoBusy = false;
  bool _enableDataCaching = true;
  final _generalFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  bool _generalValid = true;
  bool _profileValid = true;

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
    if (_saving) return;
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
    if (_saving) return;
    if (_section == SettingsSection.general &&
        !(_generalFormKey.currentState?.validate() ?? false)) {
      setState(() => _generalValid = false);
      return;
    }
    if (_section == SettingsSection.profile &&
        !(_profileFormKey.currentState?.validate() ?? false)) {
      setState(() => _profileValid = false);
      return;
    }
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
        ).showSnackBar(SnackBar(content: Text(AppErrorMessage.from(error))));
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
        sessionTimeoutMinutes: int.tryParse(_general[6].text.trim())!,
        autoLogoutWarningMinutes: int.tryParse(_general[7].text.trim())!,
        enableDataCaching: _enableDataCaching,
        updatedAtUtc: widget.controller.settings!.system.updatedAtUtc,
      ),
    );
    await widget.controller.savePreferences(widget.token, _preferences!);
    widget.controller.replaceSettings(
      AdminSettings(
        system: saved,
        preferences: _preferences!,
        profile: widget.controller.settings!.profile,
      ),
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
        hasProfilePhoto: widget.controller.settings!.profile.hasProfilePhoto,
        profilePhotoUpdatedAtUtc:
            widget.controller.settings!.profile.profilePhotoUpdatedAtUtc,
      ),
    );
    await widget.controller.savePreferences(widget.token, _preferences!);
    widget.controller.replaceSettings(
      AdminSettings(
        system: widget.controller.settings!.system,
        preferences: widget.controller.settings!.preferences,
        profile: saved,
      ),
    );
    widget.onProfileUpdated(saved);
  }

  Future<void> _savePassword() async {
    if (_saving) return;
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
        ).showSnackBar(SnackBar(content: Text(AppErrorMessage.from(error))));
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
        if (widget.showHeader) ...[
          AppPageHeader(
            icon: LucideIcons.settings,
            title: 'Settings',
            subtitle: 'Manage your system preferences and configurations.',
            action: widget.headerAction,
          ),
          const SizedBox(height: 20),
        ],
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
        child: Form(
          key: _generalFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: () {
            final valid = _generalFormKey.currentState?.validate() ?? false;
            if (valid != _generalValid) setState(() => _generalValid = valid);
          },
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
                  onChanged: _setPreferences,
                ),
                const SizedBox(height: 16),
                FormatSettingsSection(
                  value: _preferences!,
                  onChanged: _setPreferences,
                ),
                const SizedBox(height: 16),
                SessionSettingsSection(
                  controllers: _general,
                  itemsPerPage: _preferences!.defaultItemsPerPage,
                  enableDataCaching: _enableDataCaching,
                  onItemsChanged: (value) => setState(() {
                    _preferences = _copyPreferences(itemsPerPage: value);
                    _dirty = _hasChanges;
                  }),
                  onCachingChanged: (value) => setState(() {
                    _enableDataCaching = value;
                    _dirty = _hasChanges;
                  }),
                  onChanged: _markDirty,
                ),
                const SizedBox(height: 16),
                _footerInfo(),
              ],
            ),
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
        child: Form(
          key: _profileFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: () {
            final valid = _profileFormKey.currentState?.validate() ?? false;
            if (valid != _profileValid) setState(() => _profileValid = valid);
          },
          child: SingleChildScrollView(
            child: ProfileSettingsSection(
              controllers: _profile,
              preferences: _preferences!,
              onPreferencesChanged: _setPreferences,
              onChanged: _markDirty,
              profile: widget.controller.settings!.profile,
              token: widget.token,
              photoBusy: _photoBusy,
              onChangePhoto: _changePhoto,
              onRemovePhoto: _removePhoto,
            ),
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
            valid:
                (_section != SettingsSection.general || _generalValid) &&
                (_section != SettingsSection.profile || _profileValid),
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

  void _markDirty() => setState(() => _dirty = _hasChanges);

  void _setPreferences(AdminPreferences value) => setState(() {
    _preferences = value;
    _dirty = _hasChanges;
  });

  bool get _hasChanges {
    if (_section == SettingsSection.security) {
      return _security.any((controller) => controller.text.isNotEmpty);
    }
    final baseline = widget.controller.settings!;
    if (!_samePreferences(_preferences!, baseline.preferences)) return true;
    if (_section == SettingsSection.profile) {
      return _profile[0].text != baseline.profile.firstName ||
          _profile[1].text != baseline.profile.lastName ||
          _profile[3].text != baseline.profile.phoneNumber;
    }
    final system = baseline.system;
    final values = [
      system.systemName,
      system.systemShortName,
      system.companyName,
      system.companyEmail,
      system.companyPhone,
      system.timezone,
      '${system.sessionTimeoutMinutes}',
      '${system.autoLogoutWarningMinutes}',
    ];
    for (var index = 0; index < values.length; index++) {
      if (_general[index].text != values[index]) return true;
    }
    return _enableDataCaching != system.enableDataCaching;
  }

  bool _samePreferences(AdminPreferences a, AdminPreferences b) =>
      a.themeMode == b.themeMode &&
      a.sidebarStyle == b.sidebarStyle &&
      a.dateFormat == b.dateFormat &&
      a.timeFormat == b.timeFormat &&
      a.firstDayOfWeek == b.firstDayOfWeek &&
      a.numberFormat == b.numberFormat &&
      a.defaultItemsPerPage == b.defaultItemsPerPage &&
      a.timezone == b.timezone;

  Future<void> _changePhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    if (file.bytes == null) {
      _showPhotoError('The selected file could not be read.');
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      _showPhotoError('Profile photo cannot be larger than 2 MB.');
      return;
    }
    setState(() => _photoBusy = true);
    try {
      final saved = await widget.controller.service.uploadProfilePhoto(
        widget.token,
        file.bytes!,
        file.name,
      );
      _replaceProfile(saved);
      widget.onProfileUpdated(saved);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (error) {
      _showPhotoError(AppErrorMessage.from(error));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _photoBusy = true);
    try {
      final saved = await widget.controller.service.deleteProfilePhoto(
        widget.token,
      );
      _replaceProfile(saved);
      widget.onProfileUpdated(saved);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo removed.')));
      }
    } catch (error) {
      _showPhotoError(AppErrorMessage.from(error));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _replaceProfile(AdminProfile profile) {
    widget.controller.replaceSettings(
      AdminSettings(
        system: widget.controller.settings!.system,
        preferences: widget.controller.settings!.preferences,
        profile: profile,
      ),
    );
  }

  void _showPhotoError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
