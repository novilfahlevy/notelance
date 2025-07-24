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

    database ??= await openDatabase(path, version: 1,
      onCreate: (Database db, int version) async {
        // When creating the db, create the table
        String query = 'CREATE TABLE Folders (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)';
        await db.execute(query);
      },
    );
  } catch (e) {
    logger.e(e.toString());
  }
}
