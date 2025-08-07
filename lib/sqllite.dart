import 'package:notelance/local_database_service.dart';
import 'package:logger/logger.dart';

var logger = Logger();

// Backward compatibility - provide access to the database instance
// This allows existing code to work with minimal changes
LocalDatabaseService get localDatabase => LocalDatabaseService.instance;

/// Initialize the database - call this in main()
Future<void> loadSQLite() async {
  try {
    await LocalDatabaseService.instance.initialize();
    logger.d('Database service loaded successfully');
  } catch (e) {
    logger.e('Error loading database service: ${e.toString()}');
    rethrow;
  }
}