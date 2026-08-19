import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum QrScanSource { camera, gallery }

class ScanQrSourceSheet extends StatelessWidget {
  const ScanQrSourceSheet({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Scan QR', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.x),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            key: const ValueKey('scan-camera'),
            leading: const Icon(LucideIcons.camera),
            title: const Text('Camera'),
            subtitle: const Text('Scan using camera'),
            onTap: () => Navigator.of(context).pop(QrScanSource.camera),
          ),
          ListTile(
            key: const ValueKey('scan-gallery'),
            leading: const Icon(LucideIcons.image),
            title: const Text('Gallery'),
            subtitle: const Text('Choose QR image from gallery'),
            onTap: () => Navigator.of(context).pop(QrScanSource.gallery),
          ),
        ],
      ),
    ),
  );
}
