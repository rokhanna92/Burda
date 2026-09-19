import 'package:flutter/material.dart';

import '../theme/edition.dart';
import '../widgets/page_furniture.dart';

/// The colophon: rank, the édition the app is printed in, and the archive.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.edition});

  final Edition edition;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('Colophon', edition: edition),
          const SizedBox(height: 4),
          ScreenTitle('Profile', edition: edition),
        ],
      ),
    );
  }
}
