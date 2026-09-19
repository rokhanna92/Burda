import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/note_provider.dart';
import 'providers/contents_provider.dart';
import 'providers/magazine_provider.dart';
import 'providers/make_provider.dart';
import 'providers/measure_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/tonight_provider.dart';
import 'shell/burda_shell.dart';
import 'theme/app_theme.dart';

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
        ChangeNotifierProvider(create: (_) => ContentsProvider()..load()),
        ChangeNotifierProvider(create: (_) => MakeProvider()..load()),
        ChangeNotifierProvider(create: (_) => MeasureProvider()..load()),
        ChangeNotifierProvider(create: (_) => TonightProvider()..load()),
        ChangeNotifierProvider(create: (_) => NoteProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Burda Style',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(theme.edition),
          home: const BurdaShell(),
        ),
      ),
    );
  }
}
