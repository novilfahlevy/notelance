import 'package:logger/logger.dart';
import 'package:notelance/local_database.dart';
import 'package:notelance/models/note.dart';

var logger = Logger();

class NoteLocalRepository {
  Future<List<Note>> get() async {
    final database = LocalDatabase.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'is_deleted = 0',
        orderBy: 'title ASC',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getNotes method: $e');
      rethrow;
    }
  }

  Future<List<Note>> getWithRemoteId() async {
    final database = LocalDatabase.instance.database;
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

  Future<List<Note>> getWithoutRemoteId() async {
    final database = LocalDatabase.instance.database;
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

  Future<List<Note>> getUncategorized() async {
    final database = LocalDatabase.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'category_id IS NULL AND is_deleted = 0',
        orderBy: 'title ASC',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getUncategorizedNotes method: $e');
      rethrow;
    }
  }

  Future<List<Note>> getRecentFirst({ int limit = 10 }) async {
    final database = LocalDatabase.instance.database;
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

  Future<List<Note>> search(String query) async {
    final database = LocalDatabase.instance.database;
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

  Future<int> count() async {
    final database = LocalDatabase.instance.database;
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

  Future<int> countByCategory(int categoryId) async {
    final database = LocalDatabase.instance.database;
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

  Future<List<Note>> getByCategory(int categoryId) async {
    final database = LocalDatabase.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'category_id = ? AND is_deleted = 0',
        whereArgs: [categoryId],
        orderBy: 'title ASC',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getNotesByCategory method: $e');
      rethrow;
    }
  }

  Future<Note?> getById(int noteId) async {
    final database = LocalDatabase.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final noteFromDb = await database.query(
        'Notes',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [noteId],
      );

      if (noteFromDb.isEmpty) return null;

      return Note.fromJson(noteFromDb.first);
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getNoteById method: $e');
      rethrow;
    }
  }

  Future<bool> checkNoteIsNotExistedByRemoteId(int remoteId) async {
    final database = LocalDatabase.instance.database;
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

  Future<Note> create({
    required String title,
    required String content,
    int? categoryId,
    int? remoteId,
    String? createdAt,
    String? updatedAt,
    int? isDeleted
  }) async {
    final database = LocalDatabase.instance.database;
    if (database == null) throw Exception('Database not initialized');

    final now = DateTime.now().toUtc().toIso8601String();
    final Map<String, dynamic> noteData = {
      'title': title,
      'content': content,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
      'is_deleted': isDeleted ?? 0
    };

    if (categoryId != null) {
      noteData['category_id'] = categoryId;
    }

    if (remoteId != null) {
      noteData['remote_id'] = remoteId;
    }

    try {
      final noteId = await database.insert('Notes', noteData);
      noteData['id'] = noteId;

      logger.d('Note created with ID: $noteId');
      return Note.fromJson(noteData);
    } catch (e) {
      logger.e('Error in NoteLocalRepository.create method: $e');
      rethrow;
    }
  }

  Future<Note> update(
      int id,
      {
        String? title,
        String? content,
        int? categoryId,
        int? remoteId,
        int? isDeleted,
        required String updatedAt
      }
  ) async {
    final database = LocalDatabase.instance.database;
    if (database == null) throw Exception('Database not initialized');

    final Map<String, dynamic> noteData = { 'updated_at': updatedAt };

    if (title != null) noteData['title'] = title;
    if (content != null) noteData['content'] = content;
    if (remoteId != null) noteData['remote_id'] = remoteId;
    if (isDeleted != null) noteData['is_deleted'] = isDeleted;

    noteData['category_id'] = categoryId;

    try {
      final updatedRows = await database.update(
        'Notes',
        noteData,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (updatedRows == 0) {
        throw Exception('Note not found');
      }

      logger.d('Note updated: ID $id');

      final updatedNote = await getById(id);
      return updatedNote!;
    } catch (e) {
      logger.e('Error in NoteLocalRepository.update method: $e');
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    final database = LocalDatabase.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final updatedRows = await database.update(
        'Notes',
        { 'is_deleted': 1, 'updated_at': DateTime.now().toUtc().toIso8601String() },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (updatedRows == 0) {
        throw Exception('Note not found');
      }

      logger.d('Note soft-deleted: ID $id');
    } catch (e) {
      logger.e('Error in NoteLocalRepository.delete method: $e');
      rethrow;
    }
  }

  Future<List<Note>> getDeleted() async {
    final database = LocalDatabase.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'is_deleted = 1',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
    } catch (e) {
      logger.e(
          'Error in NoteLocalRepository.getDeleted method: $e');
      rethrow;
    }
  }

  Future<void> hardDelete(int noteId) async {
    final database = LocalDatabase.instance.database;
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
      logger.e('Error in NoteLocalRepository.hardDelete method: $e');
      rethrow;
    }
  }

  Future<List<Note>> getWithTrashed() async {
    final database = LocalDatabase.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> notesFromDb = await database.query(
        'Notes',
        where: 'is_deleted IN (0, 1)',
      );

      return notesFromDb.map((noteJson) => Note.fromJson(noteJson)).toList();
    } catch (e) {
      logger.e('Error in NoteLocalRepository.getWithTrashed method: $e');
      rethrow;
    }
  }
}