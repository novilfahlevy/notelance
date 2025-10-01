// Dart core libraries
import 'dart:isolate';
import 'dart:ui';

// Flutter framework
import 'package:flutter/material.dart';

// Third-party packages
import 'package:logger/logger.dart';
import 'package:notelance/helpers.dart';
import 'package:notelance/repositories/note_local_repository.dart';
import 'package:provider/provider.dart';

// Local project imports
import 'package:notelance/pages/categories_page.dart';
import 'package:notelance/config.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/pages/note_editor_page.dart';
import 'package:notelance/pages/notes_page.dart';
import 'package:notelance/view_models/main_page_view_model.dart';
import 'package:notelance/repositories/category_local_repository.dart';
import 'package:notelance/pages/search_page.dart';
import 'package:notelance/local_database.dart';
import 'package:notelance/synchronization.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

var logger = Logger();

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

  Widget _buildSyncStatusWidget() {
    final mainPageViewModel = context.read<MainPageViewModel>();
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

  @override
  Widget build(BuildContext context) {
    final mainPageViewModel = context.watch<MainPageViewModel>();

    return DefaultTabController(
      length: mainPageViewModel.categories.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notelance'),
          actions: [
            _buildSyncStatusWidget(),
            IconButton(
              icon: Icon(Icons.search, size: 24,),
              onPressed: () => mainPageViewModel.showSearchPage(context),
            ),
            IconButton(
              icon: Icon(Icons.label, size: 24),
              onPressed: () => mainPageViewModel.showCategoriesPage(context),
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
          onPressed: () => mainPageViewModel.openNoteEditorDialog(context),
          foregroundColor: Colors.black,
          backgroundColor: Colors.amber,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}