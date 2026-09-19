import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/issue_address.dart';
import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/cover_tile.dart';
import '../widgets/page_furniture.dart';
import '../widgets/sheet_scaffold.dart';

/// Looking an issue up by its address: number, slash, year.
class SearchSheet extends StatefulWidget {
  const SearchSheet({super.key, required this.edition});

  final Edition edition;

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// The issue the query points at, once it is a whole address.
  ///
  /// Nothing is looked up until the year is four digits long, so the result
  /// does not flicker between volumes as the year is typed.
  Magazine? _found(MagazineProvider magazines) {
    final parts = _query.text.split('/');
    if (parts.length < 2 || parts[1].length != 4) return null;
    final issue = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (issue == null || year == null) return null;
    return magazines.byId('$issue-$year');
  }

  bool get _addressComplete {
    final parts = _query.text.split('/');
    return parts.length >= 2 &&
        parts[1].length == 4 &&
        int.tryParse(parts[0]) != null &&
        int.tryParse(parts[1]) != null;
  }

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;
    final magazines = context.watch<MagazineProvider>();
    final found = _found(magazines);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeading(
          edition: edition,
          eyebrow: 'Look up',
          title: 'Find an issue',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _query,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          // Type the digits; the slash is put in for you.
          inputFormatters: const [_AddressFormatter()],
          onChanged: (_) => setState(() {}),
          style: AppType.serif(
            size: 40,
            weight: 300,
            tabular: true,
            color: edition.ink,
          ),
          cursorColor: edition.accent,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            hintText: '2/2024',
            hintStyle: AppType.serif(
              size: 40,
              weight: 300,
              tabular: true,
              color: edition.inkAt(30),
            ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: edition.ink, width: 2),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: edition.ink, width: 2),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: edition.ink, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'the issue number, then the year',
          textAlign: TextAlign.center,
          style: AppType.serif(
            size: 14,
            italic: true,
            color: edition.inkAt(60),
          ),
        ),
        if (found != null) ...[
          const SizedBox(height: 22),
          CoverIn(
            duration: const Duration(milliseconds: 300),
            child: _Result(edition: edition, magazine: found),
          ),
        ] else if (_addressComplete) ...[
          const SizedBox(height: 24),
          Text(
            'Nothing filed at that address yet.',
            textAlign: TextAlign.center,
            style: AppType.serif(
              size: 18,
              italic: true,
              color: edition.inkAt(65),
            ),
          ),
        ],
      ],
    );
  }
}

/// Keeps the field reading as an address while it is typed.
class _AddressFormatter extends TextInputFormatter {
  const _AddressFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = IssueAddress.format(newValue.text);
    return TextEditingValue(
      text: formatted,
      // An address is short and typed left to right, so the caret belongs at
      // the end: it cannot be left stranded before a slash that just appeared.
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.edition, required this.magazine});

  final Edition edition;
  final Magazine magazine;

  @override
  Widget build(BuildContext context) {
    final nav = BurdaNav.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        nav.closeSheet();
        nav.push(IssuePage(magazine.id));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: edition.inkAt(25))),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 74,
              child: CoverTile(
                magazine: magazine,
                edition: edition,
                numeralSize: 26,
                depth: CoverDepth.flat,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No. ${magazine.issue} · ${magazine.year}',
                    overflow: TextOverflow.ellipsis,
                    style: AppType.serif(
                      size: 24,
                      weight: 500,
                      height: 1,
                      color: edition.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    magazine.isOwned ? 'in the collection' : 'still missing',
                    overflow: TextOverflow.ellipsis,
                    style: AppType.serif(
                      size: 15,
                      italic: true,
                      color: edition.inkAt(65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('→', style: AppType.serif(size: 24, color: edition.ink)),
          ],
        ),
      ),
    );
  }
}
