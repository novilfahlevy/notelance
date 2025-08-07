import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';

class LocalDatabaseService {
  static LocalDatabaseService? _instance;
  static Database? _database;
  static final Logger _logger = Logger();

  // Private constructor
  LocalDatabaseService._();

  // Singleton pattern
  static LocalDatabaseService get instance {
    _instance ??= LocalDatabaseService._();
    return _instance!;
  }

  // Get database instance
  Database? get database => _database;

  /// Initialize the database
  Future<void> initialize() async {
    if (_database != null) return;

    try {
      if (Platform.isWindows || Platform.isLinux) {
        // Initialize FFI
        sqfliteFfiInit();
      }

      // Change the default factory. On iOS/Android, if not using `sqlite_flutter_lib` you can forget
      // this step, it will use the sqlite version available on the system.
      databaseFactory = databaseFactoryFfi;

      var databasesPath = await getDatabasesPath();
      String path = join(databasesPath, 'main.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (Database db, int version) async {
          // When creating the db, create the table
          await _createTables(db);
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          // Handle database upgrades if needed
          await _createTables(db);
        },
        onOpen: (Database db) async {
          // Ensure tables exist even if database already existed
          await _ensureTablesExist(db);
        },
      );

      _logger.d('Database initialized successfully');
    } catch (e) {
      _logger.e('Error initializing database: ${e.toString()}');
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _createTables(Database db) async {
    try {
      // Create Categories table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          created_at INTEGER
        )
      ''');

      // Create Notes table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          content TEXT,
          category_id INTEGER,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (category_id) REFERENCES Categories (id) ON DELETE CASCADE
        )
      ''');

      _logger.d('Tables created successfully');
    } catch (e) {
      _logger.e('Error creating tables: ${e.toString()}');
      rethrow;
    }
  }

  /// Ensure tables exist in existing database
  Future<void> _ensureTablesExist(Database db) async {
    try {
      // Check if Categories table exists
      var result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='Categories'"
      );

      if (result.isEmpty) {
        // Table doesn't exist, create it
        await _createTables(db);
        _logger.d('Tables created in existing database');
      }
    } catch (e) {
      _logger.e('Error ensuring tables exist: ${e.toString()}');
      rethrow;
    }
  }

  /// Close the database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _logger.d('Database closed');
    }
  }

  // ============================================================================
  // CATEGORY OPERATIONS
  // ============================================================================

  /// Get all categories
  Future<List<Category>> getCategories() async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> categoriesFromDb = await _database!.query(
        'Categories',
        orderBy: 'name ASC',
      );

      return categoriesFromDb
          .map((categoryJson) => Category.fromJson(categoryJson))
          .toList();
    } catch (e) {
      _logger.e('Error getting categories: $e');
      rethrow;
    }
  }

  /// Create a new category
  Future<Category> createCategory(String name) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      final categoryId = await _database!.insert(
        'Categories',
        {
          'name': name,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
      );

      _logger.d('Category created with ID: $categoryId');

      return Category(id: categoryId, name: name);
    } catch (e) {
      _logger.e('Error creating category: $e');
      rethrow;
    }
  }

  /// Update a category
  Future<void> updateCategory(int categoryId, String newName) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      final updatedRows = await _database!.update(
        'Categories',
        {'name': newName},
        where: 'id = ?',
        whereArgs: [categoryId],
      );

      if (updatedRows == 0) {
        throw Exception('Category not found');
      }

      _logger.d('Category updated: ID $categoryId -> $newName');
    } catch (e) {
      _logger.e('Error updating category: $e');
      rethrow;
    }
  }

  /// Delete a category and all its notes
  Future<void> deleteCategory(int categoryId) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      // First delete all notes in this category
      await _database!.delete(
        'Notes',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );

      // Then delete the category
      final deletedRows = await _database!.delete(
        'Categories',
        where: 'id = ?',
        whereArgs: [categoryId],
      );

      if (deletedRows == 0) {
        throw Exception('Category not found');
      }

      _logger.d('Category deleted: ID $categoryId');
    } catch (e) {
      _logger.e('Error deleting category: $e');
      rethrow;
    }
  }

  /// Get notes count for a category
  Future<int> getCategoryNotesCount(int categoryId) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      final result = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM Notes WHERE category_id = ?',
        [categoryId],
      );

      return result.first['count'] as int;
    } catch (e) {
      _logger.e('Error getting category notes count: $e');
      rethrow;
    }
  }

  // ============================================================================
  // NOTE OPERATIONS
  // ============================================================================

  /// Get all notes for a category
  Future<List<Note>> getNotesByCategory(int categoryId) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await _database!.query(
        'Notes',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'updated_at DESC',
      );

      return notesFromDb
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
    } catch (e) {
      _logger.e('Error getting notes by category: $e');
      rethrow;
    }
  }

  /// Get a single note by ID
  Future<Note?> getNoteById(int noteId) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      final noteFromDb = await _database!.query(
        'Notes',
        where: 'id = ?',
        whereArgs: [noteId],
      );

      if (noteFromDb.isEmpty) return null;

      return Note.fromJson(noteFromDb.first);
    } catch (e) {
      _logger.e('Error getting note by ID: $e');
      rethrow;
    }
  }

  /// Create a new note
  Future<int> createNote(Note note) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      final noteId = await _database!.insert(
        'Notes',
        note.toJson(),
      );

      _logger.d('Note created with ID: $noteId');
      return noteId;
    } catch (e) {
      _logger.e('Error creating note: $e');
      rethrow;
    }
  }

  /// Update a note
  Future<void> updateNote(Note note) async {
    if (_database == null) throw Exception('Database not initialized');
    if (note.id == null) throw Exception('Note ID is required for update');

    try {
      final updatedRows = await _database!.update(
        'Notes',
        note.toJson(),
        where: 'id = ?',
        whereArgs: [note.id],
      );

      if (updatedRows == 0) {
        throw Exception('Note not found');
      }

      _logger.d('Note updated: ID ${note.id}');
    } catch (e) {
      _logger.e('Error updating note: $e');
      rethrow;
    }
  }

  /// Delete a note
  Future<void> deleteNote(int noteId) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      final deletedRows = await _database!.delete(
        'Notes',
        where: 'id = ?',
        whereArgs: [noteId],
      );

      if (deletedRows == 0) {
        throw Exception('Note not found');
      }

      _logger.d('Note deleted: ID $noteId');
    } catch (e) {
      _logger.e('Error deleting note: $e');
      rethrow;
    }
  }

  /// Search notes by title or content
  Future<List<Note>> searchNotes(String query) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await _database!.query(
        'Notes',
        where: 'title LIKE ? OR content LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'updated_at DESC',
      );

      return notesFromDb
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
    } catch (e) {
      _logger.e('Error searching notes: $e');
      rethrow;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check if database is initialized
  bool get isInitialized => _database != null;

  /// Get database path (for debugging purposes)
  Future<String> getDatabasePath() async {
    var databasesPath = await getDatabasesPath();
    return join(databasesPath, 'main.db');
  }

  /// Execute raw SQL query (use with caution)
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      return await _database!.rawQuery(sql, arguments);
    } catch (e) {
      _logger.e('Error executing raw query: $e');
      rethrow;
    }
  }

  /// Execute raw SQL insert/update/delete (use with caution)
  Future<int> rawExecute(String sql, [List<Object?>? arguments]) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      return await _database!.rawUpdate(sql, arguments);
    } catch (e) {
      _logger.e('Error executing raw SQL: $e');
      rethrow;
    }
  }
}