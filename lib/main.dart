import 'package:flutter/material.dart';
import 'package:notelance/search_page.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:notelance/sqflite.dart';
import 'package:notelance/categories_management_page.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/note_editor_page.dart';
import 'package:notelance/notes_page.dart';
import 'package:notelance/notifiers/categories_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

var logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await LocalDatabaseService.instance.initialize();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const NotelanceApp());
}

class NotelanceApp extends StatelessWidget {
  const NotelanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CategoriesNotifier(),
      child: MaterialApp(
          title: 'Notelance',
          debugShowCheckedModeBanner: false,

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),

          routes: {
            Notelance.path: (_) => Notelance(),
            NoteEditorPage.path: (_) => NoteEditorPage(),
            SearchPage.path: (_) => SearchPage()
          },

          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ]
      ),
    );
  }
}

class Notelance extends StatefulWidget {
  const Notelance({super.key});

  static final String path = '/';

  @override
  State<Notelance> createState() => _NotelanceState();
}

class _NotelanceState extends State<Notelance> {
  final LocalDatabaseService _databaseService = LocalDatabaseService.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.watch<CategoriesNotifier>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  final TextEditingController _searchController = TextEditingController();
  List<Category> _categories = [];

  Future<void> _loadCategories() async {
    if (!_databaseService.isInitialized) return;

    final categoriesNotifier = context.read<CategoriesNotifier>();

    if (categoriesNotifier.shouldReloadCategories) {
      try {
        final categories = await _databaseService.getCategories();
        setState(() {
          _categories = categories;
        });
      } catch (e) {
        logger.e(e.toString());
      }
    }
  }

  void _openNoteEditorDialog(BuildContext context) async {
    Navigator.pushNamed(context, NoteEditorPage.path);
  }

  void _showCategoriesManagementPage(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => CategoriesManagementPage(categories: _categories),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _showSearchPage(context) {
    Navigator.pushNamed(context, SearchPage.path);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notelance'),
          actions: [
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () => _showSearchPage(context),
            ),
            IconButton(
              icon: Icon(Icons.label),
              onPressed: () => _showCategoriesManagementPage(context),
            ),
            const SizedBox(width: 10)
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Umum'),
              ..._categories.map((category) => Tab(text: category.name))
            ],
          ),
        ),
        body: TabBarView(
          children: [
            NotesPage(key: const ValueKey('notes_page_general')),

            ..._categories.map((category) => NotesPage(
                key: ValueKey('notes_page_${category.id}_${category.order}'),
                category: category
            )),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openNoteEditorDialog(context),
          foregroundColor: Colors.white,
          backgroundColor: Colors.orangeAccent,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}