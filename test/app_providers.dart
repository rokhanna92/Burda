import 'package:burda/models/note_provider.dart';
import 'package:burda/providers/contents_provider.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/providers/make_provider.dart';
import 'package:burda/providers/theme_provider.dart';
import 'package:burda/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// The providers the app runs on, all built on one test database.
///
/// Lives here rather than in each test file because a widget test missing a
/// provider fails at run time with a ProviderNotFoundException rather than at
/// compile time, and there are seven files that would otherwise have to
/// remember every time the app grows one.
class TestApp {
  TestApp(DatabaseService service)
    : magazines = MagazineProvider(database: service),
      contents = ContentsProvider(database: service),
      makes = MakeProvider(database: service),
      notes = NoteProvider(database: service);

  final MagazineProvider magazines;
  final ContentsProvider contents;
  final MakeProvider makes;
  final NoteProvider notes;

  Future<void> load() async {
    await magazines.load();
    await contents.load();
    await makes.load();
    await notes.load();
  }

  /// What a pumped widget tree is wrapped in.
  List<SingleChildWidget> get providers => [
    ChangeNotifierProvider.value(value: magazines),
    ChangeNotifierProvider.value(value: contents),
    ChangeNotifierProvider.value(value: makes),
    ChangeNotifierProvider.value(value: notes),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
  ];
}
