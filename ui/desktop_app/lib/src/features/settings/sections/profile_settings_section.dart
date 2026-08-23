import 'package:flutter/material.dart';
import '../admin_settings_models.dart';
import '../widgets/settings_section_card.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../core/api_client.dart';

class ProfileSettingsSection extends StatelessWidget {
  const ProfileSettingsSection({
    super.key,
    required this.controllers,
    required this.preferences,
    required this.onPreferencesChanged,
    required this.onChanged,
    required this.profile,
    required this.token,
    required this.onChangePhoto,
    required this.onRemovePhoto,
    required this.photoBusy,
  });
  final List<TextEditingController> controllers;
  final AdminPreferences preferences;
  final ValueChanged<AdminPreferences> onPreferencesChanged;
  final VoidCallback onChanged;
  final AdminProfile profile;
  final String token;
  final VoidCallback onChangePhoto, onRemovePhoto;
  final bool photoBusy;

  AdminPreferences _copy({
    String? date,
    String? time,
    String? week,
    String? number,
    String? timezone,
  }) => AdminPreferences(
    themeMode: preferences.themeMode,
    sidebarStyle: preferences.sidebarStyle,
    dateFormat: date ?? preferences.dateFormat,
    timeFormat: time ?? preferences.timeFormat,
    firstDayOfWeek: week ?? preferences.firstDayOfWeek,
    numberFormat: number ?? preferences.numberFormat,
    defaultItemsPerPage: preferences.defaultItemsPerPage,
    timezone: timezone ?? preferences.timezone,
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SettingsSectionCard(
        title: 'Personal Information',
        subtitle: 'Manage your personal information and contact details.',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 840
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _field('First Name', 0, width),
                _field('Last Name', 1, width),
                _field('Email', 2, width, enabled: false),
                _field('Phone', 3, width),
                _dropdown(
                  width,
                  'Timezone',
                  preferences.timezone,
                  const [
                    'Europe/Sarajevo',
                    'Europe/Zagreb',
                    'Europe/Belgrade',
                    'UTC',
                  ],
                  (value) => onPreferencesChanged(_copy(timezone: value)),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      SettingsSectionCard(
        title: 'Account Preferences',
        subtitle: 'Configure your personal display preferences.',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 500
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _dropdown(
                  width,
                  'Date Format',
                  preferences.dateFormat,
                  const [
                    'DD.MM.YYYY',
                    'DD/MM/YYYY',
                    'MM/DD/YYYY',
                    'YYYY-MM-DD',
                  ],
                  (value) => onPreferencesChanged(_copy(date: value)),
                ),
                _dropdown(
                  width,
                  'Time Format',
                  preferences.timeFormat,
                  const ['24h', '12h'],
                  (value) => onPreferencesChanged(_copy(time: value)),
                ),
                _dropdown(
                  width,
                  'Number Format',
                  preferences.numberFormat,
                  const ['1,234.56', '1.234,56'],
                  (value) => onPreferencesChanged(_copy(number: value)),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      SettingsSectionCard(
        title: 'Profile Identity',
        subtitle:
            'Your initials are used anywhere an administrator avatar is shown.',
        child: Row(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .1),
              child: ClipOval(
                child: SizedBox.square(
                  dimension: 84,
                  child: profile.hasProfilePhoto
                      ? Image.network(
                          '${ApiClient.baseUrl}/api/admin/settings/profile/photo?v=${profile.profilePhotoUpdatedAtUtc?.millisecondsSinceEpoch ?? 0}',
                          headers: {'Authorization': 'Bearer $token'},
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _initialsFallback(context),
                        )
                      : _initialsFallback(context),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fullName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Administrator',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: photoBusy ? null : onChangePhoto,
                        icon: photoBusy
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(
                          profile.hasProfilePhoto
                              ? 'Replace photo'
                              : 'Upload photo',
                        ),
                      ),
                      if (profile.hasProfilePhoto)
                        TextButton.icon(
                          onPressed: photoBusy ? null : onRemovePhoto,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'JPG or PNG, maximum 2 MB.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  String get _fullName =>
      '${controllers[0].text} ${controllers[1].text}'.trim();
  String get _initials => [
    controllers[0].text,
    controllers[1].text,
  ].where((v) => v.isNotEmpty).map((v) => v[0].toUpperCase()).join();
  Widget _initialsFallback(BuildContext context) => Center(
    child: Text(
      _initials.isEmpty ? 'A' : _initials,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
  Widget _field(String label, int index, double width, {bool enabled = true}) =>
      SizedBox(
        width: width,
        child: TextFormField(
          controller: controllers[index],
          enabled: enabled,
          onChanged: (_) => onChanged(),
          validator: enabled
              ? (value) => value == null || value.trim().isEmpty
                    ? '$label is required.'
                    : null
              : null,
          decoration: InputDecoration(labelText: label),
        ),
      );
  Widget _dropdown(
    double width,
    String label,
    String value,
    List<String> values,
    ValueChanged<String> changed,
  ) => SizedBox(
    width: width,
    child: AppDropdownField<String>(
      value: value,
      label: label,
      items: values
          .map((item) => AppDropdownItem(value: item, label: item))
          .toList(),
      onChanged: changed,
    ),
  );
}
