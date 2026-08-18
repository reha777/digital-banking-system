import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

const maximumProfilePhotoSizeBytes = 2 * 1024 * 1024;
const profilePhotoAllowedExtensions = ['jpg', 'jpeg', 'png'];

class PickedProfilePhoto {
  const PickedProfilePhoto({required this.fileName, required this.bytes});
  final String fileName;
  final Uint8List bytes;
}

class ProfilePhotoPickerException implements Exception {
  const ProfilePhotoPickerException(this.message);
  final String message;
}

void validateProfilePhoto(String fileName, Uint8List bytes) {
  final extension = fileName.split('.').last.toLowerCase();
  if (!profilePhotoAllowedExtensions.contains(extension)) {
    throw const ProfilePhotoPickerException(
      'Only JPG and PNG photos are allowed.',
    );
  }
  if (bytes.isEmpty) {
    throw const ProfilePhotoPickerException('Selected photo is empty.');
  }
  if (bytes.length > maximumProfilePhotoSizeBytes) {
    throw const ProfilePhotoPickerException(
      'Profile photo cannot be larger than 2 MB.',
    );
  }
}

Future<PickedProfilePhoto?> pickProfilePhoto() async {
  final result = await FilePicker.pickFiles(
    allowMultiple: false,
    withData: true,
    type: FileType.custom,
    allowedExtensions: profilePhotoAllowedExtensions,
  );
  final file = result?.files.single;
  if (file == null) return null;
  final bytes = file.bytes;
  if (bytes == null) {
    throw const ProfilePhotoPickerException(
      'Selected photo could not be loaded.',
    );
  }
  validateProfilePhoto(file.name, bytes);
  return PickedProfilePhoto(fileName: file.name, bytes: bytes);
}
