import 'package:flutter/material.dart';

import '../../auth/auth_models.dart';
import '../../../widgets/profile_avatar.dart';
import '../profile_photo_picker.dart';
import '../settings_service.dart';
import '../widgets/settings_widgets.dart';
import 'personal_information_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user,
    this.service,
    this.onOpenCards,
    this.onProfileUpdated,
    this.accessToken,
    this.photoPicker,
  });

  final AuthUser user;
  final SettingsService? service;
  final VoidCallback? onOpenCards;
  final VoidCallback? onProfileUpdated;
  final String? accessToken;
  final Future<PickedProfilePhoto?> Function()? photoPicker;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late CustomerProfile _profile = _fromUser(widget.user);
  bool _loading = false;
  bool _uploadingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.service != null) _load();
  }

  static CustomerProfile _fromUser(AuthUser user) => CustomerProfile(
    id: user.id,
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    phoneNumber: user.phoneNumber,
    role: user.role,
    hasProfilePhoto: user.hasProfilePhoto,
    profilePhotoUpdatedAtUtc: user.profilePhotoUpdatedAtUtc,
  );

  Future<void> _changePhoto() async {
    if (_uploadingPhoto || widget.service == null) return;
    try {
      final photo = await (widget.photoPicker ?? pickProfilePhoto)();
      if (photo == null || !mounted) return;
      setState(() => _uploadingPhoto = true);
      final profile = await widget.service!.uploadProfilePhoto(
        fileName: photo.fileName,
        bytes: photo.bytes,
      );
      if (!mounted) return;
      setState(() => _profile = profile);
      widget.onProfileUpdated?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } on ProfilePhotoPickerException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo could not be updated.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.service!.getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      if (mounted) setState(() => _error = 'Profile could not be refreshed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '${_profile.firstName} ${_profile.lastName}'.trim();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const SettingsHeader(title: 'Profile'),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 28),
            Row(
              children: [
                ProfileAvatar(
                  firstName: _profile.firstName,
                  lastName: _profile.lastName,
                  hasProfilePhoto: _profile.hasProfilePhoto,
                  accessToken: widget.accessToken,
                  photoVersion: _profile.profilePhotoUpdatedAtUtc,
                  size: 60,
                  borderWidth: 0,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? 'Banking customer' : fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_profile.role.isNotEmpty)
                        Text(
                          _profile.role,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (widget.service != null)
                        TextButton(
                          key: const ValueKey('change-profile-photo'),
                          onPressed: _uploadingPhoto ? null : _changePhoto,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                          ),
                          child: _uploadingPhoto
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _profile.hasProfilePhoto
                                      ? 'Change Photo'
                                      : 'Upload Photo',
                                ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_error != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            const SizedBox(height: 24),
            SettingsNavigationTile(
              label: 'Personal Information',
              icon: Icons.person_outline,
              onTap: widget.service == null
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PersonalInformationPage(
                            profile: _profile,
                            onSave:
                                ({
                                  required firstName,
                                  required lastName,
                                  required phoneNumber,
                                }) async {
                                  final updated = await widget.service!
                                      .updateProfile(
                                        firstName: firstName,
                                        lastName: lastName,
                                        phoneNumber: phoneNumber,
                                      );
                                  widget.onProfileUpdated?.call();
                                  return updated;
                                },
                          ),
                        ),
                      );
                      final user = widget.service == null
                          ? null
                          : await widget.service!.getProfile();
                      if (mounted && user != null) {
                        setState(() => _profile = user);
                      }
                    },
            ),
            SettingsNavigationTile(
              label: 'Banks and Cards',
              icon: Icons.credit_card_outlined,
              onTap: widget.onOpenCards,
            ),
            const SettingsNavigationTile(
              label: 'Notifications',
              icon: Icons.notifications_none,
              value: 'API required',
            ),
            const SettingsNavigationTile(
              label: 'Address',
              icon: Icons.location_on_outlined,
              value: 'API required',
            ),
            SettingsNavigationTile(
              label: 'Settings',
              icon: Icons.settings_outlined,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
