import 'package:flutter/material.dart';
import 'package:notelance/add_category_dialog.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/notes_page.dart';
import 'package:notelance/sqllite.dart';
import 'package:logger/logger.dart';

var logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSQLite();
  runApp(const NotelanceApp());
}

class NotelanceApp extends StatelessWidget {
  const NotelanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notelance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Notelance(),
    );
  }
}

class Notelance extends StatefulWidget {
  const Notelance({super.key});

  @override
  State<Notelance> createState() => _NotelanceState();
}

class _NotelanceState extends State<Notelance> {
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  final TextEditingController _searchController = TextEditingController();

  List<Category> _categories = [];

  // Load categories from database
  Future<void> _loadCategories() async {
    if (database == null) return;

    try {
      final List<Map<String, dynamic>> categoriesFromDb = await database!.query(
        'Categories',
      );
      setState(() {
        _categories = categoriesFromDb
            .map((folderJson) => Category.fromJson(folderJson))
            .toList();
      });
    } catch (e) {
      logger.e(e.toString());
    }
  }

  void _showAddCategoryDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AddCategoryDialog(
          onAdded: (category) {
            setState(() {
              _categories.add(category);
            });
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _categories.isEmpty
        ? Scaffold(
            appBar: AppBar(title: const Text('Notelance')),
            body: const Center(
              child: Text('No categories yet. Add one to get started!'),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showAddCategoryDialog(context),
              foregroundColor: Colors.white,
              backgroundColor: Colors.orangeAccent,
              child: const Icon(Icons.add),
            ),
          )
        : DefaultTabController(
            length: _categories.length,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Notelance'),
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
                onPressed: () => _showAddCategoryDialog(context),
                foregroundColor: Colors.white,
                backgroundColor: Colors.orangeAccent,
                child: const Icon(Icons.add),
              ),
            ),
          );
  }
}
