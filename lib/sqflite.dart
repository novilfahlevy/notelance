import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';

import 'package:path_provider/path_provider.dart';

class LocalDatabaseService {
  static LocalDatabaseService? _instance;
  static Database? _database;
  static final Logger _logger = Logger();

  /// Private constructor
  LocalDatabaseService._();

  /// Singleton pattern
  static LocalDatabaseService get instance {
    _instance ??= LocalDatabaseService._();
    return _instance!;
  }

  /// Get database instance
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

      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'main.db');

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

  /// Create database tables (updated version)
  Future<void> _createTables(Database db) async {
    try {
      // Create Categories table with order column
      await db.execute('''
      CREATE TABLE IF NOT EXISTS Categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        name TEXT NOT NULL,
        order_index INTEGER DEFAULT 0,
        created_at INTEGER
      )
    ''');

      // Create Notes table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS Notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
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
      } else {
        // Check if order_index column exists, if not add it
        var columns = await db.rawQuery("PRAGMA table_info(Categories)");
        bool hasOrderColumn = columns.any((column) => column['name'] == 'order_index');

        if (!hasOrderColumn) {
          await db.execute('ALTER TABLE Categories ADD COLUMN order_index INTEGER DEFAULT 0');
          _logger.d('Added order_index column to Categories table');
        }
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

// Backward compatibility - provide access to the database instance
// This allows existing code to work with minimal changes
LocalDatabaseService get localDatabase => LocalDatabaseService.instance;