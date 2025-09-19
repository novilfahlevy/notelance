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
        where: 'category_id IS NULL AND is_deleted = 0',
        orderBy: 'updated_at DESC',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
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
        where: 'category_id = ? AND is_deleted = 0',
        whereArgs: [categoryId],
        orderBy: 'updated_at DESC',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
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
        where: 'remote_id IS NOT NULL AND is_deleted = 0',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getNotesWithRemoteId method: $e');
      rethrow;
    }
  }

  Future<bool> checkNoteIsNotExistedByRemoteId(int remoteId) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> result = await database.query(
        'Notes',
        columns: ['COUNT(*) as count'],
        where: 'remote_id = ?',
        whereArgs: [remoteId],
      );

      if (result.isNotEmpty) {
        final count = result.first['count'] as int?;
        return count != null && count <= 0;
      }

      return true;
    } catch (e) {
      logger.e(
          'Error in NoteLocalRepository.checkNoteIsNotExistedByRemoteId method: $e');
      rethrow;
    }
  }

  Future<List<Note>> getNotesWithoutRemoteId() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'remote_id IS NULL AND is_deleted = 0',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
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
      final updatedRows = await database.update(
        'Notes',
        {'is_deleted': 1},
        where: 'id = ?',
        whereArgs: [noteId],
      );

      if (updatedRows == 0) {
        throw Exception('Note not found');
      }

      logger.d('Note soft-deleted: ID $noteId');
    } catch (e) {
      logger.e('Error in NoteLocalRepository.deleteNote method: $e');
      rethrow;
    }
  }

  Future<void> hardDeleteNote(int noteId) async {
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

      logger.d('Note hard-deleted: ID $noteId');
    } catch (e) {
      logger.e('Error in NoteLocalRepository.hardDeleteNote method: $e');
      rethrow;
    }
  }

  Future<List<Note>> searchNotes(String query) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: '(title LIKE ? OR content LIKE ?) AND is_deleted = 0',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'updated_at DESC',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.searchNotes method: $e');
      rethrow;
    }
  }

  Future<List<Note>> getNotes() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'is_deleted = 0',
        orderBy: 'updated_at DESC',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getNotes method: $e');
      rethrow;
    }
  }

  Future<int> getNotesCount() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM Notes WHERE is_deleted = 0',
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
        'SELECT COUNT(*) as count FROM Notes WHERE category_id = ? AND is_deleted = 0',
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
        where: 'is_deleted = 0',
        orderBy: 'updated_at DESC',
        limit: limit,
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
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

  Future<List<Note>> getNotesMarkedForDeletion() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'is_deleted = 1',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
    } catch (e) {
      logger.e(
          'Error in NoteLocalRepository.getNotesMarkedForDeletion method: $e');
      rethrow;
    }
  }
}