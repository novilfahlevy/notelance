import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:notelance/local_database_service.dart';
import 'package:notelance/categories_management_page.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/note_editor_page.dart';
import 'package:notelance/notes_page.dart';
import 'package:notelance/notifiers/categories_notifier.dart';

var logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabaseService.instance.initialize();
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
            NoteEditorPage.path: (_) => NoteEditorPage()
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

  void _showCategoriesManagementPage(BuildContext context) async {
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CategoriesNotifier>();

    if (_categories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notelance')),
        body: const Center(
          child: Text('Belum ada kategori. Buat satu kategori terlebih dulu.'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openNoteEditorDialog(context),
          foregroundColor: Colors.white,
          backgroundColor: Colors.orangeAccent,
          child: const Icon(Icons.add),
        ),
      );
    }

    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notelance'),
          actions: [
            IconButton(
              icon: Icon(Icons.label),
              onPressed: () => _showCategoriesManagementPage(context),
            ),
            const SizedBox(width: 10)
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _categories
                .map((category) => Tab(text: category.name))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: _categories
              .map((category) => NotesPage(category: category))
              .toList(),
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