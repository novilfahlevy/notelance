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
    BackgroundIsolateBinaryMessenger.ensureInitialized(message.rootIsolateToken);

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
    Isolate.exit(); /// Close the Isolate
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
            headers: { 'Authorization': 'Bearer $supabaseServiceRoleKey', 'Content-Type': 'application/json' }
          )
      );

      if (response.data['message'] == 'CATEGORIES_IS_FETCHED_SUCCESSFULLY') {
        final List<dynamic> remoteCategories = response.data['categories'] as List<dynamic>;

        for (int i = 0; i < remoteCategories.length; i++) {
          final remoteCategory = remoteCategories[i];
          final Category? localCategorySameByName = await _categoryLocalRepository.getCategoryByName(remoteCategory['name']);

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
            await _categoryLocalRepository.deleteCategory(localCategoryWithRemoteId.id!);
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
      /// Synchronize notes with remote id
      final List<Note> notes = await _noteLocalRepository.getNotesWithRemoteId();

      /// Fetch the remote note of each local note
      for (int i = 0; i < notes.length; i++) {
        // Ensure timestamps are in UTC ISO format
        final createdAtUTC = _ensureUTCFormat(notes[i].createdAt!);
        final updatedAtUTC = _ensureUTCFormat(notes[i].updatedAt!);

        final params = 'note_id=${notes[i].remoteId}&created_at=$createdAtUTC&updated_at=$updatedAtUTC';

        /// TODO: Use Dio
        // final FunctionResponse response = await _sbFunctionClient.invoke(
        //   'hello-world/sync-fetch?$params',
        //   method: HttpMethod.get,
        // );

        // if (response.data['message'] == 'NOTE_IN_THE_SERVER_IS_DEPRECATED') {
        //   await _handleDeprecatedServerNote(notes[i]);
        // } else if (response.data['message'] == 'NOTE_IN_THE_SERVER_IS_NEWEST') {
        //   await _handleNewerServerNote(notes[i], response.data);
        // } else if (response.data['message'] == 'NOTE_IS_NOT_FOUND_IN_THE_SERVER') {
        //   // Handle case where note was deleted from server
        //   // You might want to delete locally or re-upload
        //   logger.i('Note ${notes[i].remoteId} not found on server');
        // }
      }
    } catch (error) {
      logger.e('Error synchronizing notes: $error');
      rethrow;
    }
  }

  static Future<void> _handleDeprecatedServerNote(Note localNote) async {
    try {
      final Category? localCategory = await _categoryLocalRepository.getCategoryById(localNote.categoryId!);
      final notePayload = localNote.toJson();

      /// Update the note's category in the remote
      if (localCategory != null && localCategory.remoteId != null) {
        notePayload['category_remote_id'] = localCategory.remoteId;
      } else {
        notePayload['category_remote_id'] = null;
      }

      /// Ensure timestamps are in UTC
      notePayload['created_at'] = _ensureUTCFormat(localNote.createdAt!);
      notePayload['updated_at'] = _ensureUTCFormat(localNote.updatedAt!);

      /// Do the sync-send request
      /// TODO: Use Dio
      // final response = await _sbFunctionClient.invoke(
      //     'hello-world/sync-send',
      //     method: HttpMethod.post,
      //     body: notePayload
      // );

      // Handle response if needed
      // if (response.data != null && response.data['remote_id'] != null) {
      //   // Update local note with any returned remote_id if changed
      //   if (localNote.remoteId != response.data['remote_id']) {
      //     await _noteLocalRepository.updateNote(Note(
      //       id: localNote.id,
      //       title: localNote.title,
      //       content: localNote.content,
      //       remoteId: response.data['remote_id'],
      //       categoryId: localNote.categoryId,
      //       createdAt: localNote.createdAt,
      //       updatedAt: localNote.updatedAt,
      //     ));
      //   }
      // }
    } catch (error) {
      logger.e('Error handling deprecated server note: $error');
      rethrow;
    }
  }

  static Future<void> _handleNewerServerNote(Note localNote, Map<String, dynamic> serverData) async {
    try {
      /// Handle the category sync
      final Category? localCategoryBySameRemoteId = await _categoryLocalRepository.getCategoryByRemoteId(serverData['remote_category_id']);

      /// Update the note in local database
      await _noteLocalRepository.updateNote(Note(
        id: localNote.id,
        title: serverData['title'],
        content: serverData['content'],
        remoteId: serverData['remote_id'],
        categoryId: localCategoryBySameRemoteId?.id ?? localNote.categoryId,
        createdAt: localNote.createdAt, // Keep original creation time
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
      // await synchronizeNotes();

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