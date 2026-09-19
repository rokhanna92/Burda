import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';
import '../widgets/sheet_scaffold.dart';

/// Sending an issue out of the house: who has it, dated today.
///
/// A sheet rather than a field on the issue screen, because the page scrolls
/// and the sheet is what already lifts clear of the keyboard. The date is today
/// and is not editable: a loan is remembered to the week, not to the minute,
/// and a date stepper would be more furniture than the fact deserves.
class LendSheet extends StatefulWidget {
  const LendSheet({super.key, required this.edition, required this.magazine});

  final Edition edition;
  final Magazine magazine;

  @override
  State<LendSheet> createState() => _LendSheetState();
}

class _LendSheetState extends State<LendSheet> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _lend() async {
    final nav = BurdaNav.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      nav.showToast('Say who has it first');
      return;
    }

    await context.read<MagazineProvider>().lendIssue(widget.magazine.id, name);
    if (!mounted) return;
    nav.closeSheet();
    nav.showToast(
      'No. ${widget.magazine.issue} / ${widget.magazine.year} is with $name',
    );
  }

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeading(
          edition: edition,
          eyebrow: 'Lending',
          title: 'No. ${widget.magazine.issue} / ${widget.magazine.year}',
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: edition.inkAt(18))),
          ),
          child: TextField(
            controller: _name,
            autofocus: true,
            // The field only ever holds a person's name, for the same reason
            // the search field puts the slash in for her.
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _lend(),
            style: AppType.serif(size: 28, weight: 500, color: edition.ink),
            cursorColor: edition.accent,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintText: 'Who has it?',
              hintStyle: AppType.serif(
                size: 28,
                weight: 500,
                color: edition.inkAt(35),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Dated today. It is still yours, just not here.',
          style: AppType.serif(
            size: 15,
            italic: true,
            color: edition.inkAt(60),
          ),
        ),
        const SizedBox(height: 20),
        BurdaButton(
          edition: edition,
          label: 'Lend it out',
          filled: true,
          onTap: _lend,
        ),
      ],
    );
  }
}
