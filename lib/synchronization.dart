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

  static Future<void> _synchronizeLocalCategoriesWithRemote() async {
    try {
      // Get all local categories
      final List<Category> localCategories = await _categoryLocalRepository.getCategories();

      // Prepare categories data for sync endpoint
      final List<Map<String, dynamic>> categoriesPayload = localCategories
          .map((category) {
        return {
          'id': category.id.toString(),
          'remote_id': category.remoteId?.toString() ?? '',
          'name': category.name,
          'order_index': category.orderIndex ?? 0,
          'is_deleted': 0, // Assuming categories are not soft-deleted in your current implementation
          'updated_at': DateTime.now().toUtc().toIso8601String(), // You might want to add updated_at field to Category model
          'created_at': DateTime.now().toUtc().toIso8601String(), // You might want to add created_at field to Category model
        };
      })
          .toList();

      // Make sync request
      final Response response = await _httpClient.post(
        '$supabaseFunctionUrl/categories/sync',
        data: { 'categories': categoriesPayload },
        options: Options(
          headers: {
            'Authorization': 'Bearer $supabaseServiceRoleKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data['state'] == 'CATEGORIES_HAVE_SYNCED') {
        final List<dynamic> categoryResponses = response.data['categories'] as List<dynamic>;

        for (final categoryResponse in categoryResponses) {
          final Map<String, dynamic> responseData = categoryResponse as Map<String, dynamic>;
          final String localCategoryId = responseData['id'];
          final Category localCategory = localCategories.firstWhere(
                (cat) => cat.id.toString() == localCategoryId,
                orElse: () => throw Exception('Local category not found'),
          );
          await _handleCategoryResponse(localCategory, responseData);
        }
      } else if (response.data['state'] == 'CATEGORIES_SYNC_IS_FAILED') {
        throw Exception('Categories sync failed: ${response.data['errorMessage']}');
      } else {
        throw Exception('Unexpected response state: ${response.data['state']}');
      }
    } catch (error) {
      logger.e('Error synchronizing categories: $error');
      rethrow;
    }
  }

  static Future<void> _handleCategoryResponse(Category localCategory, Map<String, dynamic> responseData) async {
    try {
      switch (responseData['state']) {
        case 'CATEGORY_ID_IS_NOT_PROVIDED':
        // Category was created on server, update local with remote_id
          if (responseData['remote_id'] != null) {
            await _categoryLocalRepository.updateCategory(
              localCategory.id!,
              remoteId: int.parse(responseData['remote_id'].toString()),
            );
            logger.i('Updated local category ${localCategory.name} with remote_id: ${responseData['remote_id']}');
          } else {
            logger.e('Failed to create category ${localCategory.name} on server: ${responseData['message']}');
          }
          break;

        case 'CATEGORY_IN_THE_REMOTE_IS_NEWER':
        // Update local category with server data
          await _categoryLocalRepository.updateCategory(
            localCategory.id!,
            name: responseData['name'],
            orderIndex: responseData['order_index'],
          );
          logger.i('Updated local category ${localCategory.name} with newer server data');
          break;

        case 'CATEGORY_IN_THE_REMOTE_IS_DEPRECATED':
          if (responseData['message'] != null && responseData['message'].contains('updated')) {
            logger.i('Successfully updated server category for ${localCategory.name}');
          } else {
            logger.e('Failed to update server category for ${localCategory.name}: ${responseData['message']}');
          }
          break;

        case 'CATEGORY_ID_IS_NOT_VALID':
          logger.e('Invalid remote_id for category ${localCategory.name}: ${responseData['remote_id']}');
          break;

        case 'AN_ERROR_OCCURED_IN_THIS_CATEGORY':
          logger.e('Error occurred for category ${localCategory.name}: ${responseData['errorMessage']}');
          break;

        case 'CATEGORY_IS_NOT_FOUND_IN_THE_REMOTE':
          logger.i('Category ${localCategory.name} not found on server - it may have been deleted remotely');
          // Optionally handle deletion - you might want to delete locally or re-create on server
          break;

        case 'CATEGORY_IN_THE_REMOTE_IS_THE_SAME':
          logger.d('Category ${localCategory.name} is in sync');
          break;

        default:
          logger.w('Unknown sync state for category ${localCategory.name}: ${responseData['state']}');
      }
    } catch (error) {
      logger.e('Error handling note response for ${localCategory.name}: $error');
    }
  }

  static Future<void> _fetchNewCategoriesFromRemote() async {
    try {
      final Response response = await _httpClient.get(
        '$supabaseFunctionUrl/categories',
        options: Options(
          headers: {
            'Authorization': 'Bearer $supabaseServiceRoleKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data['message'] == 'CATEGORIES_IS_FETCHED_SUCCESSFULLY') {
        final List<dynamic> remoteCategories = response.data['categories'] as List<dynamic>;

        for (final remoteCategoryData in remoteCategories) {
          final int remoteId = remoteCategoryData['remote_id'] ?? remoteCategoryData['id'];
          final Category? existingCategory = await _categoryLocalRepository.getCategoryByRemoteId(remoteId);

          if (existingCategory == null) {
            // Create new category locally
            await _categoryLocalRepository.createCategory(
              name: remoteCategoryData['name'],
              orderIndex: remoteCategoryData['order_index'],
              remoteId: remoteId,
            );
            logger.i('Created new local category from server: ${remoteCategoryData['name']}');
          }
        }
      }
    } catch (error) {
      logger.e('Error fetching new categories from server: $error');
      // Don't rethrow here as this is a supplementary operation
    }
  }

  static Future<void> _synchronizeLocalNotesWithRemote() async {
    try {
      // Get all local notes that need syncing (both deleted and active)
      final List<Note> localNotes = await _noteLocalRepository.getNotes();

      // Prepare notes data for sync endpoint
      final List<Map<String, dynamic>> notesPayload = localNotes.map((note) {
        return {
          'id': note.id.toString(),
          'remote_id': note.remoteId?.toString() ?? '',
          'title': note.title,
          'content': note.content ?? '',
          'category_id': note.categoryId?.toString() ?? '',
          'is_deleted': note.isDeleted,
          'updated_at': _ensureUTCFormat(note.updatedAt ?? note.createdAt ?? DateTime.now().toIso8601String()),
          'created_at': _ensureUTCFormat(note.createdAt ?? DateTime.now().toIso8601String()),
        };
      }).toList();

      // Make sync request
      final Response response = await _httpClient.post(
        '$supabaseFunctionUrl/notes/sync',
        data: { 'notes': notesPayload },
        options: Options(
          headers: {
            'Authorization': 'Bearer $supabaseServiceRoleKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data['state'] == 'NOTES_HAVE_SYNCED') {
        final List<dynamic> noteResponses = response.data['notes'] as List<dynamic>;

        for (final noteResponse in noteResponses) {
          final Map<String, dynamic> noteData = noteResponse as Map<String, dynamic>;
          final String localNoteId = noteData['id'];
          final Note localNote = localNotes.firstWhere(
                (localNote) => localNote.id.toString() == localNoteId,
                orElse: () => throw Exception('Local note not found'),
          );
          await _handleNoteResponse(localNote, noteData);
        }
      } else if (response.data['state'] == 'NOTES_SYNC_IS_FAILED') {
        throw Exception('Notes sync failed: ${response.data['errorMessage']}');
      } else {
        throw Exception('Unexpected response state: ${response.data['state']}');
      }
    } catch (error) {
      logger.e('Error synchronizing notes: $error');
      rethrow;
    }
  }

  static Future<void> _handleNoteResponse(Note localNote, Map<String, dynamic> responseData) async {
    try {
      switch (responseData['state']) {
        case 'NOTE_ID_IS_NOT_PROVIDED':
          // Note was created on server, update local with remote_id
          if (responseData['remoteId'] != null) {
            final updatedNote = localNote.copyWith(
              remoteId: int.parse(responseData['remoteId'].toString()),
              createdAt: responseData['created_at'] ?? localNote.createdAt,
              updatedAt: responseData['updated_at'] ?? localNote.updatedAt,
            );
            await _noteLocalRepository.updateNote(updatedNote);
            logger.i('Updated local note ${localNote.title} with remote_id: ${responseData['remoteId']}');
          } else {
            logger.e('Failed to create note ${localNote.title} on server: ${responseData['message']}');
          }
        break;

        case 'NOTE_IN_THE_REMOTE_IS_NEWER':
          // Update local note with server data
          final updatedNote = localNote.copyWith(
            remoteId: responseData['remote_id'],
            title: responseData['title'],
            content: responseData['content'],
            isDeleted: responseData['is_deleted'],
            updatedAt: responseData['updated_at'],
          );

          // Handle category update
          final String? remoteCategoryId = responseData['category_id']?.toString();
          if (remoteCategoryId != null && remoteCategoryId.isNotEmpty) {
            final Category? localCategory = await _categoryLocalRepository.getCategoryByRemoteId(int.parse(remoteCategoryId));
            if (localCategory != null) {
              updatedNote.categoryId = localCategory.id;
            }
          } else {
            updatedNote.categoryId = null;
          }

          await _noteLocalRepository.updateNote(updatedNote);
          logger.i('Updated local note ${localNote.title} with newer server data');
        break;

        case 'NOTE_IN_THE_REMOTE_IS_DEPRECATED':
          if (responseData['message'] != null && responseData['message'].contains('updated')) {
            logger.i('Successfully updated server note for ${localNote.title}');
          } else {
            logger.e('Failed to update server note for ${localNote.title}: ${responseData['message']}');
          }
        break;

        case 'NOTE_ID_IS_NOT_VALID':
          logger.e('Invalid remote_id for note ${localNote.title}: ${responseData['remote_id']}');
        break;

        case 'AN_ERROR_OCCURED_IN_THIS_NOTE':
          logger.e('Error occurred for note ${localNote.title}: ${responseData['errorMessage']}');
        break;

        case 'NOTE_IS_NOT_FOUND_IN_THE_REMOTE':
          logger.i('Note ${localNote.title} not found on server - it may have been deleted remotely');
          // If the note was marked for deletion locally and doesn't exist on server, hard delete it
          if (localNote.isDeleted == 1) {
            await _noteLocalRepository.hardDeleteNote(localNote.id!);
            logger.i('Hard deleted local note ${localNote.title} as it was not found on server');
          }
        break;

        case 'NOTE_IN_THE_REMOTE_IS_THE_SAME':
          logger.d('Note ${localNote.title} is in sync');
          // If note was marked for deletion and successfully synced, soft-delete it
          if (localNote.isDeleted == 1) {
            await _noteLocalRepository.deleteNote(localNote.id!);
            logger.i('Hard deleted synced note ${localNote.title}');
          }
        break;

        default:
          logger.w('Unknown sync state for note ${localNote.title}: ${responseData['state']}');
      }
    } catch (error) {
      logger.e('Error handling note response for ${localNote.title}: $error');
    }
  }

  static Future<void> _fetchNewNotesFromRemote() async {
    try {
      final Response response = await _httpClient.get(
        '$supabaseFunctionUrl/notes',
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
          final int currentRemoteNoteId = remoteNoteData['remote_id'] as int;

          // Check if a local note with this remote_id exists
          if (await _noteLocalRepository.checkNoteIsNotExistedByRemoteId(currentRemoteNoteId)) {
            // Parse timestamps from server
            final String createdAtStringFromServer = remoteNoteData['created_at'] as String;
            final String updatedAtStringFromServer = remoteNoteData['updated_at'] as String;

            final DateTime createdAtUtc = DateTime.parse(createdAtStringFromServer);
            final DateTime updatedAtUtc = DateTime.parse(updatedAtStringFromServer);

            final String createdAtLocal = createdAtUtc.toLocal().toIso8601String();
            final String updatedAtLocal = updatedAtUtc.toLocal().toIso8601String();

            final Note newNote = Note(
              title: remoteNoteData['title'],
              content: remoteNoteData['content'],
              remoteId: currentRemoteNoteId,
              createdAt: createdAtLocal,
              updatedAt: updatedAtLocal,
              isDeleted: remoteNoteData['is_deleted'] ?? 0,
            );

            // Attach the category to the note
            final int? remoteCategoryId = remoteNoteData['remote_category_id'];
            if (remoteCategoryId != null) {
              Category? localCategory = await _categoryLocalRepository.getCategoryByRemoteId(remoteCategoryId);
              localCategory ??= await _categoryLocalRepository.createCategory(
                  name: remoteNoteData['remote_category_name'],
                  remoteId: remoteCategoryId,
                  orderIndex: remoteNoteData['remote_category_order_index']
              );
              newNote.categoryId = localCategory.id!;
            }

            // Insert the remote note to the local database
            await _noteLocalRepository.createNote(newNote);
            logger.i('Created new local note from server: ${newNote.title}');
          }
        }
      } else {
        logger.e("Failed to fetch remote notes. Status: ${response.statusCode}, Data: ${response.data}");
      }
    } catch (error) {
      logger.e("Error fetching new remote notes: $error");
      // Don't rethrow here as this is a supplementary operation
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
      /// Make it sure to syncs and fetches the categories first before the notes
      await Future.wait([
        _synchronizeLocalCategoriesWithRemote(),
        _fetchNewCategoriesFromRemote()
      ]).then((_) => Future.wait([
        _synchronizeLocalNotesWithRemote(),
        _fetchNewNotesFromRemote()
      ]));

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