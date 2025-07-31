import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';

// Global database instance
Database? database;

var logger = Logger();

Future<void> loadSQLite() async {
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

    database ??= await openDatabase(
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

    logger.d('Database loaded successfully');
  } catch (e) {
    logger.e('Error loading database: ${e.toString()}');
  }
}

Future<void> _createTables(Database db) async {
  try {
    // Create Categories table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    // You can add more tables here in the future
    // Example: Notes table
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

    logger.d('Tables created successfully');
  } catch (e) {
    logger.e('Error creating tables: ${e.toString()}');
  }
}

Future<void> _ensureTablesExist(Database db) async {
  try {
    // Check if Categories table exists
    var result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='Categories'"
    );
    
    if (result.isEmpty) {
      // Table doesn't exist, create it
      await _createTables(db);
      logger.d('Tables created in existing database');
    }
  } catch (e) {
    logger.e('Error ensuring tables exist: ${e.toString()}');
  }
}