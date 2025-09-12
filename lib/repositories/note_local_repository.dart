import 'package:logger/logger.dart';
import 'package:notelance/sqflite.dart';
import 'package:notelance/models/note.dart';

var logger = Logger();

class NoteLocalRepository {
  Future<List<Note>> getUncategorizedNotes() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'category_id IS NULL',
        orderBy: 'updated_at DESC',
      );

      return notesFromDb
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getUncategorizedNotes method: $e');
      rethrow;
    }
  }

  Future<List<Note>> getNotesByCategory(int categoryId) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'updated_at DESC',
      );

      return notesFromDb
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getNotesByCategory method: $e');
      rethrow;
    }
  }

  Future<List<Note>> getNotesWithRemoteId() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'remote_id IS NOT NULL'
      );

      return notesFromDb
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getNotesByCategory method: $e');
      rethrow;
    }
  }

  Future<List<Note>> getNotesWithoutRemoteId() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
          'Notes',
          where: 'remote_id IS NULL'
      );

      return notesFromDb
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getNotesWithoutRemoteId method: $e');
      rethrow;
    }
  }

  Future<Note?> getNoteById(int noteId) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final noteFromDb = await database.query(
        'Notes',
        where: 'id = ?',
        whereArgs: [noteId],
      );

      if (noteFromDb.isEmpty) return null;

      return Note.fromJson(noteFromDb.first);
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getNoteById method: $e');
      rethrow;
    }
  }

  Future<int> createNote(Note note) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final noteId = await database.insert(
        'Notes',
        note.toJson(),
      );

      logger.d('Note created with ID: $noteId');
      return noteId;
    } catch (e) {
      logger.e('Error in NoteLocalRepository.createNote method: $e');
      rethrow;
    }
  }

  Future<void> updateNote(Note note) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');
    if (note.id == null) throw Exception('Note ID is required for update');

    try {
      final updatedRows = await database.update(
        'Notes',
        note.toJson(),
        where: 'id = ?',
        whereArgs: [note.id],
      );

      if (updatedRows == 0) {
        throw Exception('Note not found');
      }

      logger.d('Note updated: ID ${note.id}');
    } catch (e) {
      logger.e('Error in NoteLocalRepository.updateNote method: $e');
      rethrow;
    }
  }

  Future<void> deleteNote(int noteId) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final deletedRows = await database.delete(
        'Notes',
        where: 'id = ?',
        whereArgs: [noteId],
      );

      if (deletedRows == 0) {
        throw Exception('Note not found');
      }

      logger.d('Note deleted: ID $noteId');
    } catch (e) {
      logger.e('Error in NoteLocalRepository.deleteNote method: $e');
      rethrow;
    }
  }

  Future<List<Note>> searchNotes(String query) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'title LIKE ? OR content LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'updated_at DESC',
      );

      return notesFromDb
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.searchNotes method: $e');
      rethrow;
    }
  }

  Future<List<Note>> getAllNotes() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        orderBy: 'updated_at DESC',
      );

      return notesFromDb
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getAllNotes method: $e');
      rethrow;
    }
  }

  Future<int> getNotesCount() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM Notes',
      );

      return result.first['count'] as int;
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getNotesCount method: $e');
      rethrow;
    }
  }

  Future<int> getNotesCountByCategory(int categoryId) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM Notes WHERE category_id = ?',
        [categoryId],
      );

      return result.first['count'] as int;
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getNotesCountByCategory method: $e');
      rethrow;
    }
  }

  Future<List<Note>> getRecentNotes({int limit = 10}) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        orderBy: 'updated_at DESC',
        limit: limit,
      );

      return notesFromDb
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getRecentNotes method: $e');
      rethrow;
    }
  }

  Future<void> updateNoteCategory(int noteId, int? categoryId) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final updatedRows = await database.update(
        'Notes',
        {'category_id': categoryId},
        where: 'id = ?',
        whereArgs: [noteId],
      );

      if (updatedRows == 0) {
        throw Exception('Note not found');
      }

      logger.d('Note category updated: ID $noteId, category: $categoryId');
    } catch (e) {
      logger.e('Error in NoteLocalRepository.updateNoteCategory method: $e');
      rethrow;
    }
  }
}