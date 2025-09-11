import 'dart:io';
import 'dart:isolate';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notelance/synchronization.dart';
import 'package:notelance/repositories/category_local_repository.dart';
import 'package:notelance/search_page.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:notelance/sqflite.dart';
import 'package:notelance/categories_page.dart';
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

          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF202124), // Main background
            scaffoldBackgroundColor: const Color(0xFF202124), // Scaffold background
            cardColor: const Color(0xFF303134), // Card/surface color
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Colors.amber, // Accent for FAB
              foregroundColor: Colors.black, // Icon/text on FAB
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF202124), // AppBar background
              elevation: 0, // No shadow for a flatter look
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            tabBarTheme: const TabBarThemeData(
              labelColor: Colors.amber, // Selected tab text color
              unselectedLabelColor: Colors.grey, // Unselected tab text color
              indicatorColor: Colors.amber, // Tab indicator color
            ),
            iconTheme: const IconThemeData(color: Colors.white), // Default icon color
            textTheme: const TextTheme( // Default text styles
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
              titleLarge: TextStyle(color: Colors.white),
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.amber,
              brightness: Brightness.dark,
              background: const Color(0xFF202124), // Overall background
              surface: const Color(0xFF303134), // Surfaces like cards
              primary: Colors.amber, // Primary actions/highlights
            ),
            useMaterial3: true,
          ),

          themeMode: ThemeMode.dark, // Set dark theme as default

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
      _spawnSynchronizationIsolate();
    });
  }

  Future<void> _spawnSynchronizationIsolate() async {
    if (await _hasInternetConnection()) {
      final receivePort = ReceivePort();

      try {
        final databasePath = await LocalDatabaseService.instance.getDatabasePath();
        await Isolate.spawn<SynchronizationIsolateMessage>(
            isolateEntry,
            SynchronizationIsolateMessage(
                supabaseFunctionUrl: dotenv.env['SUPABASE_FUNCTION_URL']!,
                supabaseServiceRoleKey: dotenv.env['SUPABASE_SERVICE_ROLE_KEY']!,
                sendPort: receivePort.sendPort,
                rootIsolateToken: RootIsolateToken.instance!,
                databasePath: databasePath
            )
        );

        // Listen for the result
        receivePort.listen((message) {
          if (message is Map<String, dynamic>) {
            if (message['status'] == 'success') {
              logger.i('Synchronization completed successfully');
              _loadCategories();
            } else if (message['status'] == 'error') {
              logger.e('Synchronization failed: ${message['error']}');
            }
          }

          receivePort.close();
        });
      } catch (error) {
        logger.e('Error spawning isolate: $error');
        receivePort.close();
      }
    }
  }

  Future<bool> _hasInternetConnection() async {
    if (Platform.environment.containsKey('VERCEL') || kIsWeb) return true;

    if (Platform.isAndroid || Platform.isIOS || Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      try {
        final result = await Connectivity().checkConnectivity();
        return result.first != ConnectivityResult.none;
      } catch (e) {
        logger.e('Error checking connectivity: $e');
      }
    }
    return false;
  }

  final TextEditingController _searchController = TextEditingController();
  List<Category> _categories = [];

  Future<void> _loadCategories() async {
    if (!_databaseService.isInitialized) return;

    final categoriesNotifier = context.read<CategoriesNotifier>();

    if (categoriesNotifier.shouldReloadCategories) {
      try {
        final categoryLocalRepository = CategoryLocalRepository();
        final categories = await categoryLocalRepository.getCategories();
        setState(() => _categories = categories);
      } catch (e) {
        logger.e(e.toString());
      }
    }
  }

  void _openNoteEditorDialog(BuildContext context) async {
    Navigator.pushNamed(context, NoteEditorPage.path);
  }

  void _showCategoriesPage(BuildContext context) {
    Navigator.push(
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
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () => _showSearchPage(context),
            ),
            IconButton(
              icon: Icon(Icons.label),
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
            NotesPage(key: const ValueKey('notes_page_general')),

            ..._categories.map((category) => NotesPage(
                key: ValueKey('notes_page_${category.id}_${category.orderIndex}'),
                category: category
            )),
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
