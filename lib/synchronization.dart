import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:notelance/sqflite.dart';
import 'package:notelance/repositories/category_local_repository.dart';
import 'package:notelance/repositories/note_local_repository.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';

var logger = Logger();

class SynchronizationIsolateMessage {
  final String supabaseFunctionUrl;
  final String supabaseServiceRoleKey;
  final SendPort sendPort;
  final RootIsolateToken rootIsolateToken;
  final String databasePath;

  SynchronizationIsolateMessage({
    required this.supabaseFunctionUrl,
    required this.supabaseServiceRoleKey,
    required this.sendPort,
    required this.rootIsolateToken,
    required this.databasePath,
  });
}

void isolateEntry(SynchronizationIsolateMessage message) async {
  try {
    BackgroundIsolateBinaryMessenger.ensureInitialized(
        message.rootIsolateToken);

    /// Re-initialize SQFLite
    await LocalDatabaseService.instance.initialize(
        successMessage: 'Database successfully initialized in the synchronization worker.'
    );

    /// Run synchronization
    Synchronization.supabaseFunctionUrl = message.supabaseFunctionUrl;
    Synchronization.supabaseServiceRoleKey = message.supabaseServiceRoleKey;
    final result = await Synchronization.run();

    /// Notify the main Isolate that the task is complete
    message.sendPort.send({
      'status': 'success',
      'message': 'Synchronization complete',
      'result': result
    });
  } catch (error) {
    /// Send error back to main isolate
    message.sendPort.send({
      'status': 'error',
      'message': 'Synchronization failed',
      'error': error.toString()
    });
  } finally {
    Isolate.exit();

    /// Close the Isolate
  }
}

class Synchronization {
  static final CategoryLocalRepository _categoryLocalRepository = CategoryLocalRepository();
  static final NoteLocalRepository _noteLocalRepository = NoteLocalRepository();

  static late final String supabaseFunctionUrl;
  static late final String supabaseServiceRoleKey;
  static final Dio _httpClient = Dio();

  static Future<void> synchronizeCategories() async {
    try {
      final Response response = await _httpClient.get(
          '$supabaseFunctionUrl/categories',
          options: Options(
              headers: {
                'Authorization': 'Bearer $supabaseServiceRoleKey',
                'Content-Type': 'application/json'
              }
          )
      );

      if (response.data['message'] == 'CATEGORIES_IS_FETCHED_SUCCESSFULLY') {
        final List<dynamic> remoteCategories = response
            .data['categories'] as List<dynamic>;

        for (int i = 0; i < remoteCategories.length; i++) {
          final remoteCategory = remoteCategories[i];
          final Category? localCategorySameByName = await _categoryLocalRepository
              .getCategoryByName(remoteCategory['name']);

          if (localCategorySameByName != null) {
            /// Update the local database.
            await _categoryLocalRepository.updateCategory(
                localCategorySameByName.id!,
                orderIndex: remoteCategory['order_index'],
                remoteId: remoteCategory['remote_id']
            );
          } else {
            /// Create new one into the local database.
            await _categoryLocalRepository.createCategory(
              name: remoteCategory['name'],
              orderIndex: remoteCategory['order_index'],
              remoteId: remoteCategory['remote_id'],
            );
          }
        }

        /// Deletes all local categories with remote_id that it is does not exist in the remote database.
        /// TODO: This can be more optimized. Try to optimize it later.
        final List<int> remoteIds = remoteCategories
            .map((dynamic remoteCategory) => remoteCategory['remote_id'] as int)
            .toList();

        final localCategories = await _categoryLocalRepository.getCategories();
        final List<Category> localCategoriesWithRemoteId = localCategories
            .where((Category category) => category.remoteId != null)
            .toList();

        for (int i = 0; i < localCategoriesWithRemoteId.length; i++) {
          final Category localCategoryWithRemoteId = localCategoriesWithRemoteId[i];
          if (!remoteIds.contains(localCategoryWithRemoteId.remoteId)) {
            await _categoryLocalRepository.deleteCategory(
                localCategoryWithRemoteId.id!);
          }
        }
      }
    } catch (error) {
      logger.e('Error synchronizing categories: $error');
      rethrow;
    }
  }

  static Future<void> synchronizeNotes() async {
    try {
      await _synchronizeNewLocalNotesToRemote();
      await _synchronizeNewRemoteNotesToLocal(); // Added call to the modified function

      /// Synchronize notes with remote id
      final List<Note> notes = await _noteLocalRepository.getNotesWithRemoteId();

      /// Fetch the remote note of each local note
      for (int i = 0; i < notes.length; i++) {
        // Ensure timestamps are in UTC ISO format
        final createdAtUTC = _ensureUTCFormat(notes[i].createdAt!);
        final updatedAtUTC = _ensureUTCFormat(notes[i].updatedAt!);

        final params = 'note_id=${notes[i]
            .remoteId}&created_at=$createdAtUTC&updated_at=$updatedAtUTC';

        final Response response = await _httpClient.get(
            '$supabaseFunctionUrl/sync-fetch?$params',
            options: Options(
                headers: {
                  'Authorization': 'Bearer $supabaseServiceRoleKey',
                  'Content-Type': 'application/json'
                }
            )
        );

        if (response.data['message'] == 'NOTE_IN_THE_SERVER_IS_DEPRECATED') {
          await _handleDeprecatedServerNote(notes[i]);
        } else if (response.data['message'] == 'NOTE_IN_THE_SERVER_IS_NEWEST') {
          await _handleNewerServerNote(notes[i], response.data);
        } else
        if (response.data['message'] == 'NOTE_IS_NOT_FOUND_IN_THE_SERVER') {
          // Handle case where note was deleted from server
          // You might want to delete locally or re-upload
          logger.i('Note ${notes[i].remoteId} not found on server');
        }
      }
    } catch (error) {
      logger.e('Error synchronizing notes: $error');
      rethrow;
    }
  }

  static Future<void> _synchronizeNewRemoteNotesToLocal() async {
    try {
      try {
        final Response response = await _httpClient.get(
          '$supabaseFunctionUrl/sync-fetch-all',
          options: Options(
            headers: {
              'Authorization': 'Bearer $supabaseServiceRoleKey',
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response.statusCode == 200) {
          final List<dynamic> allRemoteNotesData = response.data['notes'] as List<dynamic>;

          for (final remoteNoteRaw in allRemoteNotesData) {
            final remoteNoteData = remoteNoteRaw as Map<String, dynamic>;
            /// Assuming remote_id from server is int. Adjust if necessary.
            final int currentRemoteNoteId = remoteNoteData['remote_id'] as int;

            /// Original condition: if a local note with this remote_id does not exist.
            if (await _noteLocalRepository.checkNoteIsNotExistedByRemoteId(currentRemoteNoteId)) {
              /// Get created_at and updated_at from the current remote note
              final String createdAtStringFromServer = remoteNoteData['created_at'] as String;
              final String updatedAtStringFromServer = remoteNoteData['updated_at'] as String;

              /// Parse from String to DateTime (UTC)
              final DateTime createdAtUtc = DateTime.parse(createdAtStringFromServer);
              final DateTime updatedAtUtc = DateTime.parse(updatedAtStringFromServer);

              /// Convert to local timezone and then to ISO8601 string
              final String createdAtLocal = createdAtUtc.toLocal().toIso8601String();
              final String updatedAtLocal = updatedAtUtc.toLocal().toIso8601String();

              await _noteLocalRepository.createNote(
                Note(
                  title: remoteNoteData['title'],
                  content: remoteNoteData['content'],
                  remoteId: currentRemoteNoteId,
                  // categoryId: remoteNoteData['remote_category_id'],
                  createdAt: createdAtLocal,
                  updatedAt: updatedAtLocal,
                ),
              );
            }
          }
        } else {
          logger.e("Failed to fetch remote notes. Status: ${response.statusCode}, Data: ${response.data}");
        }
      } catch (error) {
        logger.e("Failed to fetch remote notes. Error: $error");
      }
    } catch (error) {
      logger.e('Error in _synchronizeNewRemoteNotesToLocal: $error');
      rethrow;
    }
  }

  static Future<void> _synchronizeNewLocalNotesToRemote() async {
    try {
      final List<Note> newNotes = await _noteLocalRepository.getNotesWithoutRemoteId();
      logger.i('Found ${newNotes.length} new notes to synchronize.');

      for (final newNote in newNotes) {
        try {
          final Category? localCategory = newNote.categoryId != null
              ? await _categoryLocalRepository.getCategoryById(newNote.categoryId!)
              : null;

          final Map<String, dynamic> notePayload = newNote.toJson();
          notePayload.remove('id'); /// Remove local ID, as it's for local DB only
          /// 'remote_id' is already null or not included if newNote.remoteId is null

          notePayload['remote_category_id'] = localCategory?.remoteId; // Use null-aware operator

          notePayload['created_at'] = _ensureUTCFormat(newNote.createdAt!);
          notePayload['updated_at'] = _ensureUTCFormat(newNote.updatedAt!);

          logger.i('Attempting to send new note: ${newNote.title}');

          final Response response = await _httpClient.post(
            '$supabaseFunctionUrl/sync-send',
            data: notePayload,
            options: Options(
              headers: {
                'Authorization': 'Bearer $supabaseServiceRoleKey',
                'Content-Type': 'application/json',
              },
            ),
          );

          if (response.data['message'] == 'NOTE_IS_SUCCESSFULLY_SYNCED') {
            logger.i('New note synchronized successfully. Remote ID: ${response.data['remote_id']} for local ID: ${newNote.id}');

            final String createdAtFromServer = response.data['created_at'] != null
                ? DateTime.parse(response.data['created_at']).toIso8601String()
                : newNote.createdAt!;
            final String updatedAtFromServer = response.data['updated_at'] != null
                ? DateTime.parse(response.data['updated_at']).toIso8601String()
                : newNote.updatedAt!;

            await _noteLocalRepository.updateNote(
              Note(
                id: newNote.id,
                title: newNote.title,
                content: newNote.content,
                remoteId: response.data['remote_id'],
                categoryId: newNote.categoryId,
                createdAt: createdAtFromServer,
                updatedAt: updatedAtFromServer,
              ),
            );
          } else {
            logger.e('Failed to synchronize new note ${newNote.title}. Status: ${response.statusCode}, Data: ${response.data}');
          }
        } catch (e) {
          /// Log error for a specific note and continue with the next one
          logger.e('Failed to synchronize note ${newNote.title}: $e');
          /// Optionally, you could collect these errors and report them after the loop
        }
      }
    } catch (error) {
      logger.e('Error in _synchronizeNewLocalNotesToRemote: $error');
      rethrow; /// Rethrow to allow the caller to handle it if necessary
    }
  }

  static Future<void> _handleDeprecatedServerNote(Note localNote) async {
    try {
      final Category? localCategory = localNote.categoryId != null
          ? await _categoryLocalRepository.getCategoryById(
          localNote.categoryId!)
          : null;
      final notePayload = localNote.toJson();

      /// Update the note's category in the remote
      if (localCategory != null && localCategory.remoteId != null) {
        notePayload['remote_category_id'] = localCategory.remoteId;
      } else {
        notePayload['remote_category_id'] = null;
      }

      /// Ensure timestamps are in UTC
      notePayload['created_at'] = _ensureUTCFormat(localNote.createdAt!);
      notePayload['updated_at'] = _ensureUTCFormat(localNote.updatedAt!);

      /// Do the sync-send request
      final Response response = await _httpClient.post(
          '$supabaseFunctionUrl/sync-send',
          data: notePayload,
          options: Options(
              headers: {
                'Authorization': 'Bearer $supabaseServiceRoleKey',
                'Content-Type': 'application/json'
              }
          )
      );

      // Handle response if needed
      if (response.data != null && response.data['remote_id'] != null) {
        // Update local note with any returned remote_id if changed
        if (localNote.remoteId != response.data['remote_id']) {
          await _noteLocalRepository.updateNote(Note(
            id: localNote.id,
            title: localNote.title,
            content: localNote.content,
            remoteId: response.data['remote_id'],
            categoryId: localNote.categoryId,
            createdAt: localNote.createdAt,
            updatedAt: localNote.updatedAt,
          ));
        }
      }
    } catch (error) {
      logger.e('Error handling deprecated server note: $error');
      rethrow;
    }
  }

  static Future<void> _handleNewerServerNote(Note localNote,
      Map<String, dynamic> serverData) async {
    try {
      /// Handle the category sync
      final Category? localCategoryBySameRemoteId = serverData['remote_category_id'] !=
          null
          ? await _categoryLocalRepository.getCategoryByRemoteId(
          serverData['remote_category_id'])
          : null;

      /// Update the note in local database
      await _noteLocalRepository.updateNote(Note(
        id: localNote.id,
        title: serverData['title'],
        content: serverData['content'],
        remoteId: serverData['remote_id'],
        categoryId: localCategoryBySameRemoteId?.id ?? localNote.categoryId,
        createdAt: localNote.createdAt,
        // Keep original creation time
        updatedAt: serverData['updated_at'], // Use server's updated time
      ));
    } catch (error) {
      logger.e('Error handling newer server note: $error');
      rethrow;
    }
  }

  /// Helper method to ensure timestamps are in UTC ISO format
  static String _ensureUTCFormat(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      if (dateTime.isUtc) {
        return dateTime.toIso8601String();
      } else {
        return dateTime.toUtc().toIso8601String();
      }
    } catch (error) {
      logger.e('Error parsing timestamp: $timestamp, error: $error');
      // Return current UTC time as fallback
      return DateTime.now().toUtc().toIso8601String();
    }
  }

  static Future<Map<String, dynamic>> run() async {
    try {
      await synchronizeCategories();
      await synchronizeNotes();

      return {
        'categoriesSync': 'success',
        'notesSync': 'success',
        'timestamp': DateTime.now().toUtc().toIso8601String()
      };
    } catch (error) {
      return {
        'error': error.toString(),
        'timestamp': DateTime.now().toUtc().toIso8601String()
      };
    }
  }
}
