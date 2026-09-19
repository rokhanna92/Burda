import 'package:flutter/material.dart';

import '../theme/edition.dart';
import '../widgets/page_furniture.dart';

/// Chapter two: every issue, owned or missing, grouped by year.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.edition});

  final Edition edition;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('Chapter two', edition: edition),
          const SizedBox(height: 4),
          ScreenTitle('Collection', edition: edition),
        ],
      ),
    );
  }
}
