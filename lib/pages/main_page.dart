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
  final NoteLocalRepository _noteRepository = NoteLocalRepository();

  /// To show the loading indicator when syncing.
  bool _isSyncing = false;

  /// The status of the sync operation
  bool? _isSyncSuccess;

  final TextEditingController _searchController = TextEditingController();
  List<Category> _categories = [];

  /// Notes mapped by its category.
  /// The 'Umum' category has the '0' key.
  Map<int, List<Note>> _mappedNotes = {};

  /// This key is used to uniquely identify NotesPage widgets.
  /// So if this key is changed, those notes pages would be re-rendered.
  late String _randomKey;

  @override
  void initState() {
    super.initState();

    _randomKey = DateTime.now().toUtc().microsecondsSinceEpoch.toString();

    WidgetsBinding.instance.addPostFrameCallback((_) => _spawnSynchronizationIsolate());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _spawnSynchronizationIsolate() async {
    if (await hasInternetConnection()) {
      setState(() {
        _isSyncing = true;
        _isSyncSuccess = null; // Reset sync status
      });

      final receivePort = ReceivePort();

      try {
        final databasePath = await LocalDatabase.instance.getDatabasePath();
        await Isolate.spawn<SynchronizationIsolateMessage>(
            isolateEntry,
            SynchronizationIsolateMessage(
                supabaseFunctionUrl: Config.instance.supabaseFunctionUrl,
                supabaseServiceRoleKey: Config.instance.supabaseServiceRoleKey,
                sendPort: receivePort.sendPort,
                rootIsolateToken: RootIsolateToken.instance!,
                databasePath: databasePath,
                isSentryEnabled: Config.instance.isSentryEnabled,
                sentryDsn: Config.instance.sentryDsn
            )
        );

        // Listen for the result
        receivePort.listen((message) {
          if (message is Map<String, dynamic>) {
            if (message['status'] == 'success') {
              logger.i('Synchronization completed successfully');
              _loadCategories().then((_) => _loadNotes());
              setState(() {
                _randomKey = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
                _isSyncing = false;
                _isSyncSuccess = true;
              });
            } else if (message['status'] == 'error') {
              logger.e('Synchronization failed: ${message['error']}');
              setState(() {
                _isSyncing = false;
                _isSyncSuccess = false;
              });
            }
          }
          receivePort.close();
        });
      } catch (error) {
        logger.e('Error spawning isolate: $error');
        setState(() {
          _isSyncing = false;
          _isSyncSuccess = false;
        });
        receivePort.close();
      }
    } else {
      // No internet connection
      setState(() {
        _isSyncing = false;
        _isSyncSuccess = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoryLocalRepository = CategoryLocalRepository();
      final categories = await categoryLocalRepository.get();
      setState(() => _categories = categories);
    } catch (e) {
      logger.e(e.toString());
    }
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;

    try {
      final Map<int, List<Note>> mappedNotes = {};

      mappedNotes[0] = await _noteRepository.getUncategorized();

      for (final Category category in _categories) {
        final List<Note> notes = await _noteRepository.getByCategory(category.id!);
        mappedNotes[category.id!] = notes;
      }

      setState(() => _mappedNotes = mappedNotes);
    } catch (e) {
      logger.e('Error loading notes: ${e.toString()}');
    }
  }

  void _showCategoriesPage(BuildContext context) async {
    try {
      final List<Category>? newCategories = await Navigator.push<List<Category>?>(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => CategoriesPage(categories: _categories),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.ease;

            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );

      if (newCategories != null) _reloadPage(notes: false);
    } on Exception catch (exception, stackTrace) {
      Sentry.captureException(exception, stackTrace: stackTrace);
      logger.e('Error when returned back from categories page.', error: exception, stackTrace: stackTrace);
    }
  }

  void _openNoteEditorDialog(BuildContext context) async {
    try {
      final Note? newNote = await Navigator.push<Note?>(
        context,
        MaterialPageRoute<Note?>(builder: (_) => const NoteEditorPage()),
      );

      if (newNote != null) _reloadPage();
    } on Exception catch (exception, stackTrace) {
      Sentry.captureException(exception, stackTrace: stackTrace);
      logger.e('Error when returned back from note editor (creating) page.', error: exception, stackTrace: stackTrace);
    }
  }

  void _reloadPage({
    bool categories = true,
    bool notes = true,
    bool sync = true
  }) {
    if (categories) {
      _loadCategories().then((_) {
        if (notes) _loadNotes();
      });
    } else {
      if (notes) _loadNotes();
    }

    if (sync) _spawnSynchronizationIsolate();
  }

  void _showSearchPage(context) {
    Navigator.pushNamed(context, SearchPage.path);
  }

  Widget _buildSyncStatusWidget() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isSyncing
              ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 3),
          )
              : Icon(
            _isSyncSuccess == true ? Icons.check_circle : Icons.error,
            color: _isSyncSuccess == true ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.sync, size: 24),
            onPressed: _spawnSynchronizationIsolate,
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
    // Determine FAB color based on theme
    final fabBackgroundColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.amber // Dark theme FAB color
        : Colors.orangeAccent; // Light theme FAB color (your original)
    final fabForegroundColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.black // Dark theme FAB icon color
        : Colors.white; // Light theme FAB icon color (your original)



    return DefaultTabController(
      length: _categories.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notelance'),
          actions: [
            _buildSyncStatusWidget(),
            IconButton(
              icon: Icon(Icons.search, size: 24,),
              onPressed: () => _showSearchPage(context),
            ),
            IconButton(
              icon: Icon(Icons.label, size: 24),
              onPressed: () => _showCategoriesPage(context),
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
            NotesPage(
              key: ValueKey('notes_page_general_$_randomKey'),
              category: null,
              notes: _mappedNotes.containsKey(0) ? _mappedNotes[0]! : [],
              onRefreshNotes: _loadNotes,
              onBackFromEditorPage: () async => _reloadPage(),
            ),
            ..._categories.map((Category category) {
              return NotesPage(
                key: ValueKey('notes_page_${category.id}_${category.orderIndex}_$_randomKey'),
                category: category,
                notes: _mappedNotes.containsKey(category.id) ? _mappedNotes[category.id]! : [],
                onRefreshNotes: _loadNotes,
                onBackFromEditorPage: () async => _reloadPage(),
              );
            }),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openNoteEditorDialog(context),
          foregroundColor: fabForegroundColor,
          backgroundColor: fabBackgroundColor,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}