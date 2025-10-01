// Flutter framework
import 'package:flutter/material.dart';

// Third-party packages
import 'package:provider/provider.dart';

// Local project imports
import 'package:notelance/pages/categories_page.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/pages/note_editor_page.dart';
import 'package:notelance/pages/notes_page.dart';
import 'package:notelance/view_models/main_page_view_model.dart';
import 'package:notelance/pages/search_page.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  static final String path = '/';

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  void initState() {
    super.initState();

    final mainPageViewModel = context.read<MainPageViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) => mainPageViewModel.spawnSynchronizationIsolate());
  }

  void _showSearchPage() {
    Navigator.pushNamed(context, SearchPage.path);
  }

  void _showCategoriesPage() async {
    final mainPageViewModel = context.read<MainPageViewModel>();
    try {
      final List<Category>? newCategories = await Navigator.push<List<Category>?>(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => CategoriesPage(categories: mainPageViewModel.categories),
          transitionsBuilder: _categoriesPageTransitionBuilder,
        ),
      );

      if (newCategories != null) mainPageViewModel.reloadPage(notes: false);
    } on Exception catch (exception, stackTrace) {
      Sentry.captureException(exception, stackTrace: stackTrace);
      mainPageViewModel.logger.e('Error when returned back from categories page.', error: exception, stackTrace: stackTrace);
    }
  }

  SlideTransition _categoriesPageTransitionBuilder(_, animation, _, child) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.ease;

    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(position: animation.drive(tween), child: child);
  }

  void _openNoteEditorDialog() async {
    final mainPageViewModel = context.read<MainPageViewModel>();
    try {
      final Note? newNote = await Navigator.push<Note?>(
        context,
        MaterialPageRoute<Note?>(builder: (_) => const NoteEditorPage()),
      );

      if (newNote != null) mainPageViewModel.reloadPage();
    } on Exception catch (exception, stackTrace) {
      Sentry.captureException(exception, stackTrace: stackTrace);
      mainPageViewModel.logger.e('Error when returned back from note editor (creating) page.', error: exception, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainPageViewModel = context.watch<MainPageViewModel>();

    return DefaultTabController(
      length: mainPageViewModel.categories.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notelance'),
          actions: [
            SyncStatusIndicator(),
            IconButton(
              icon: Icon(Icons.search, size: 24,),
              onPressed: _showSearchPage,
            ),
            IconButton(
              icon: Icon(Icons.label, size: 24),
              onPressed: _showCategoriesPage,
            ),
            const SizedBox(width: 10)
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Umum'),
              ...mainPageViewModel.categories.map((category) => Tab(text: category.name))
            ],
          ),
        ),
        body: TabBarView(
          children: [
            NotesPage(
              key: ValueKey('notes_page_general_$mainPageViewModel.randomKey'),
              category: null,
              notes: mainPageViewModel.mappedNotes.containsKey(0) ? mainPageViewModel.mappedNotes[0]! : [],
            ),
            ...mainPageViewModel.categories.map((Category category) {
              return NotesPage(
                key: ValueKey('notes_page_${category.id}_${category.orderIndex}_$mainPageViewModel.randomKey'),
                category: category,
                notes: mainPageViewModel.mappedNotes.containsKey(category.id) ? mainPageViewModel.mappedNotes[category.id]! : []
              );
            }),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openNoteEditorDialog,
          foregroundColor: Colors.black,
          backgroundColor: Colors.amber,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final mainPageViewModel = context.watch<MainPageViewModel>();

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mainPageViewModel.isSyncing
              ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 3),
          )
              : Icon(
            mainPageViewModel.isSyncSuccess == true ? Icons.check_circle : Icons.error,
            color: mainPageViewModel.isSyncSuccess == true ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.sync, size: 24),
            onPressed: mainPageViewModel.spawnSynchronizationIsolate,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            tooltip: 'Re-sync',
          ),
        ],
      ),
    );
  }
}
