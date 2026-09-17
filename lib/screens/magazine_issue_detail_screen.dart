import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../services/image_storage_service.dart';

/// One issue and the photos attached to it, the app's "vault".
class MagazineIssueDetailScreen extends StatefulWidget {
  const MagazineIssueDetailScreen({super.key, required this.magazineId});

  final String magazineId;

  @override
  State<MagazineIssueDetailScreen> createState() =>
      _MagazineIssueDetailScreenState();
}

class _MagazineIssueDetailScreenState extends State<MagazineIssueDetailScreen> {
  bool _picking = false;

  Future<void> _pickAndSaveImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) {
        if (mounted) _notify('No file selected.');
        return;
      }
      final path = await ImageStorageService.save(
        magazineId: widget.magazineId,
        sourcePath: picked.path,
      );
      if (!mounted) return;
      await context.read<MagazineProvider>().addUploadedImage(
        widget.magazineId,
        path,
      );
      if (mounted) _notify('Image uploaded successfully!');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _deleteImage(String path) async {
    final removed = await ImageStorageService.delete(path);
    if (!mounted) return;
    if (!removed) {
      _notify('Failed to delete image!');
      return;
    }
    await context.read<MagazineProvider>().removeUploadedImage(
      widget.magazineId,
      path,
    );
    if (mounted) _notify('Image deleted from vault!');
  }

  void _showFullScreenImage(String path) {
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

  Future<void> _confirmDelete(String path) async {
    final theme = Theme.of(context);
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
    if (confirmed ?? false) await _deleteImage(path);
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final magazine = context.select<MagazineProvider, Magazine?>(
      (provider) => provider.byId(widget.magazineId),
    );

    if (magazine == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text('Magazine not found', style: theme.textTheme.bodyLarge),
        ),
      );
    }

    final images = ImageStorageService.existing(magazine.uploadedImages);

    return Scaffold(
      appBar: AppBar(title: Text(magazine.title)),
      body: Column(
        children: [
          Expanded(
            child: images.isEmpty
                ? Center(
                    child: Text(
                      'No images uploaded yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      final path = images[index];
                      return GestureDetector(
                        onTap: () => _showFullScreenImage(path),
                        // The original offered no way to remove a photo.
                        onLongPress: () => _confirmDelete(path),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => ColoredBox(
                              color: theme.colorScheme.secondary,
                              child: const Center(
                                child: Text('Image not found'),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              onPressed: _picking ? null : _pickAndSaveImage,
              child: const Text(
                'Upload Image',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
