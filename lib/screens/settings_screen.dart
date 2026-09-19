import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/magazine_provider.dart';
import '../providers/theme_provider.dart';
import '../services/data_transfer_service.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/raining_hearts.dart';
import '../widgets/settings_modals.dart';

/// Five expandable sections: quotes, theme, data, privacy, about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// The sections that expand in place. Privacy and About open a dialog instead.
enum _Section { quotes, theme, data }

class _SettingsScreenState extends State<SettingsScreen> {
  _Section? _expanded;
  String _version = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  void _toggle(_Section section) {
    setState(() => _expanded = _expanded == section ? null : section);
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = DataTransferService.encode(
        context.read<MagazineProvider>().toExportJson(),
      );
      final location = await DataTransferService.saveExport(bytes);
      if (!mounted) return;
      _notify(
        location == null
            ? 'Export cancelled.'
            : 'Exported to ${Uri.decodeFull(location.toString())}',
      );
    } catch (error) {
      if (mounted) _notify('Error exporting: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final entries = await DataTransferService.pickImport();
      if (!mounted) return;
      if (entries == null) {
        _notify('No file selected.');
        return;
      }
      final provider = context.read<MagazineProvider>();
      final count = await provider.import(entries);
      if (!mounted) return;
      _notify('Imported successfully! $count issues.');
      // An import that completes the collection is worth celebrating too.
      if (provider.completion == 1) showRainingHearts(context);
    } catch (error) {
      if (mounted) _notify('Error importing: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final magazines = context.read<MagazineProvider>();
      final bytes = DataTransferService.encode(magazines.toExportJson());
      final result = await DataTransferService.shareExport(
        bytes,
        text:
            'I have ${magazines.ownedCount} out of ${magazines.totalCount}'
            ' in my Burda Style collection!',
        subject: 'Burda Style Collection',
      );
      if (mounted && result.status == ShareResultStatus.unavailable) {
        _notify('Sharing is not available on this device.');
      }
    } catch (error) {
      if (mounted) _notify('Error sharing: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/icon/settings.png', width: 30, height: 30),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          Center(child: Text('Settings', style: theme.textTheme.displayLarge)),
          const SizedBox(height: 14),
          Text(
            'The settings are intuitively designed\n'
            'allowing you to personalize your experience\n'
            'with ease and precision',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 30),
          _SettingsSection(
            icon: Icons.format_quote,
            title: 'Enable Quotes',
            description:
                'This is the home screen quotes and will rotate forever',
            expanded: _expanded == _Section.quotes,
            onTap: () => _toggle(_Section.quotes),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                themeProvider.quotesEnabled ? 'Quotes on' : 'Quotes off',
                style: theme.textTheme.bodyMedium,
              ),
              value: themeProvider.quotesEnabled,
              activeThumbColor: theme.colorScheme.primary,
              onChanged: themeProvider.setQuotesEnabled,
            ),
          ),
          _SettingsSection(
            icon: Icons.palette,
            title: 'Theme',
            description:
                'Tailor your app’s color theme to align with your daily '
                'workflow and preferences',
            expanded: _expanded == _Section.theme,
            onTap: () => _toggle(_Section.theme),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 14,
              childAspectRatio: 2.9,
              padding: EdgeInsets.zero,
              children: [
                for (final edition in Edition.all)
                  _Swatch(
                    edition: edition,
                    selected: edition.id == themeProvider.edition.id,
                    onTap: () => themeProvider.setEdition(edition),
                  ),
              ],
            ),
          ),
          _SettingsSection(
            icon: Icons.cloud_download,
            title: 'Data Management',
            description:
                'Export or upload your magazine data for seamless sharing and '
                'collaboration',
            expanded: _expanded == _Section.data,
            onTap: () => _toggle(_Section.data),
            child: Row(
              children: [
                Expanded(
                  child: _DataButton(
                    label: 'EXPORT',
                    onPressed: _busy ? null : _export,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DataButton(
                    label: 'IMPORT',
                    onPressed: _busy ? null : _import,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Share',
                  icon: Icon(Icons.share, color: theme.colorScheme.primary),
                  onPressed: _busy ? null : _share,
                ),
              ],
            ),
          ),
          _SettingsSection(
            icon: Icons.lock,
            title: 'Privacy & Security',
            description: 'View your privacy and security settings',
            onTap: () => showPrivacyModal(context),
          ),
          _SettingsSection(
            icon: Icons.info_outline,
            title: 'About Burda Style',
            description: 'Learn more about Burda Style and its version',
            onTap: () => showAboutModal(context, version: _version),
          ),
        ],
      ),
    );
  }
}

/// A row with an icon, a heading, a description, and either an expanding body
/// or a plain tap action.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.expanded = false,
    this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool expanded;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: theme.colorScheme.onSurface),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(description, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                Icon(
                  child == null
                      ? Icons.arrow_right
                      : expanded
                      ? Icons.arrow_drop_down
                      : Icons.arrow_right,
                  color: theme.colorScheme.onSurface,
                ),
              ],
            ),
          ),
          if (child != null)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12, left: 42),
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.edition,
    required this.selected,
    required this.onTap,
  });

  final Edition edition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: edition.paper,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 0 : 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: edition.accent, width: 3)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            edition.name,
            style: AppType.smallCaps(
              size: 15,
              trackingEm: 0.14,
              color: edition.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _DataButton extends StatelessWidget {
  const _DataButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
