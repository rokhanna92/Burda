import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/note_provider.dart';
import 'providers/magazine_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/select_year_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_navigation.dart';

void main() {
  runApp(const BurdaApp());
}

class BurdaApp extends StatelessWidget {
  const BurdaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MagazineProvider()..load()),
        ChangeNotifierProvider(create: (_) => NoteProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Burda Style',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(theme.palette),
          home: const AppShell(),
        ),
      ),
    );
  }
}

/// Holds the bottom navigation and the three destinations that are pages.
/// The dress opens the add-an-issue sheet and the arrows open the per-year
/// sheet, so neither of those replaces the current page.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const List<NavDestination> _pages = [
    NavDestination.home,
    NavDestination.years,
    NavDestination.settings,
  ];

  NavDestination _current = NavDestination.home;

  void _onSelected(NavDestination destination) {
    if (_pages.contains(destination)) {
      setState(() => _current = destination);
      return;
    }
    // TODO(next): the per-year sheet and the add-an-issue sheet.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pages.indexOf(_current),
        children: const [HomeScreen(), SelectYearScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: BottomNavigation(
        current: _current,
        onSelected: _onSelected,
      ),
    );
  }
}
