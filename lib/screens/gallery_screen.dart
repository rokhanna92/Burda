import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';
import '../services/image_storage_service.dart';

/// The vault: every photo attached to any issue, newest issue first.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final magazines = context.watch<MagazineProvider>();

    // Photo paths paired with the issue they belong to.
    final entries = [
      for (final magazine in magazines.magazines)
        for (final path in ImageStorageService.existing(
          magazine.uploadedImages,
        ))
          (magazine.id, magazine.title, path),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('VAULT')),
      body: entries.isEmpty
          ? Center(
              child: Text(
                'No images in the vault yet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final (id, title, path) = entries[index];
                return GestureDetector(
                  onTap: () => _showFullScreenImage(context, path),
                  onLongPress: () => _confirmDelete(context, id, path),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(path), fit: BoxFit.cover),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                            padding: const EdgeInsets.only(left: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete photo',
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Color(0xFFF44336),
                                  ),
                                  onPressed: () =>
                                      _confirmDelete(context, id, path),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showFullScreenImage(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String magazineId,
    String path,
  ) async {
    final theme = Theme.of(context);
    final provider = context.read<MagazineProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          'Remove this photo from the vault?',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.onSurface,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    final removed = await ImageStorageService.delete(path);
    if (!removed) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Failed to delete image!')),
        );
      return;
    }
    await provider.removeUploadedImage(magazineId, path);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Image deleted from vault!')),
      );
  }
}
