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

  static Future<void> _synchronizeCategories() async {
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
          final Map<String, dynamic> categoryData = categoryResponse as Map<String, dynamic>;
          final String localCategoryId = categoryData['id'];
          final Category localCategory = localCategories.firstWhere(
                (cat) => cat.id.toString() == localCategoryId,
                orElse: () => throw Exception('Local category not found'),
          );

          switch (categoryData['state']) {
            case 'CATEGORY_ID_IS_NOT_PROVIDED':
              // Category was created on server, update local with remote_id
              if (categoryData['remote_id'] != null) {
                await _categoryLocalRepository.updateCategory(
                  localCategory.id!,
                  remoteId: int.parse(categoryData['remote_id'].toString()),
                );
                logger.i('Updated local category ${localCategory.name} with remote_id: ${categoryData['remote_id']}');
              } else {
                logger.e('Failed to create category ${localCategory.name} on server: ${categoryData['message']}');
              }
            break;

            case 'CATEGORY_IN_THE_REMOTE_IS_NEWER':
              // Update local category with server data
              await _categoryLocalRepository.updateCategory(
                localCategory.id!,
                name: categoryData['name'],
                orderIndex: categoryData['order_index'],
              );
              logger.i('Updated local category ${localCategory.name} with newer server data');
            break;

            case 'CATEGORY_IN_THE_REMOTE_IS_DEPRECATED':
              if (categoryData['message'] != null && categoryData['message'].contains('updated')) {
                logger.i('Successfully updated server category for ${localCategory.name}');
              } else {
                logger.e('Failed to update server category for ${localCategory.name}: ${categoryData['message']}');
              }
            break;

            case 'CATEGORY_ID_IS_NOT_VALID':
              logger.e('Invalid remote_id for category ${localCategory.name}: ${categoryData['remote_id']}');
            break;

            case 'AN_ERROR_OCCURED_IN_THIS_CATEGORY':
              logger.e('Error occurred for category ${localCategory.name}: ${categoryData['errorMessage']}');
            break;

            case 'CATEGORY_IS_NOT_FOUND_IN_THE_REMOTE':
              logger.i('Category ${localCategory.name} not found on server - it may have been deleted remotely');
              // Optionally handle deletion - you might want to delete locally or re-create on server
            break;

            case 'CATEGORY_IN_THE_REMOTE_IS_THE_SAME':
              logger.d('Category ${localCategory.name} is in sync');
            break;

            default:
              logger.w('Unknown sync state for category ${localCategory.name}: ${categoryData['state']}');
          }
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

  static Future<void> _fetchNewCategoriesFromServer() async {
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

  static Future<void> _synchronizeNotes() async {
    try {
      await Future.wait([
        _notifyRemoteToDeleteNotes(),
        _synchronizeLocalNotesWithRemote(),
        _pushNewLocalNotesToRemote(),
        _fetchNewRemoteNotesToLocal()
      ]);
    } catch (error) {
      logger.e('Error synchronizing notes: $error');
      rethrow;
    }
  }

  static Future<void> _fetchNewRemoteNotesToLocal() async {
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

              final Note newNote = Note(
                title: remoteNoteData['title'],
                content: remoteNoteData['content'],
                remoteId: currentRemoteNoteId,
                createdAt: createdAtLocal,
                updatedAt: updatedAtLocal,
              );

              /// Attach the category to the note
              final int? remoteCategoryId = remoteNoteData['remote_category_id'];
              if (remoteCategoryId != null) {
                Category? localCategory = await _categoryLocalRepository.getCategoryByRemoteId(remoteCategoryId);
                localCategory ??= await _categoryLocalRepository.createCategory(
                    name: remoteNoteData['remote_category_name'],
                    remoteId: remoteNoteData['remote_category_id'],
                    orderIndex: remoteNoteData['remote_category_order_index']
                );
                newNote.categoryId = localCategory.id!;
              }

              /// Insert the remote note to the local database
              await _noteLocalRepository.createNote(newNote);
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

  static Future<void> _pushNewLocalNotesToRemote() async {
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

  static Future<void> _synchronizeLocalNotesWithRemote() async {
    try {
      /// Synchronize notes with remote id
      final List<Note> notes = await _noteLocalRepository.getNotesWithRemoteId();

      /// Fetch the remote note of each local note
      for (int i = 0; i < notes.length; i++) {
        // Ensure timestamps are in UTC ISO format
        final createdAtUTC = _ensureUTCFormat(notes[i].createdAt!);
        final updatedAtUTC = _ensureUTCFormat(notes[i].updatedAt!);

        final params = 'note_id=${notes[i].remoteId}&created_at=$createdAtUTC&updated_at=$updatedAtUTC';

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
        } else if (response.data['message'] == 'NOTE_IS_NOT_FOUND_IN_THE_SERVER') {
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

  static Future<void> _handleNewerServerNote(Note localNote, Map<String, dynamic> serverData) async {
    try {
      final Note remoteUpdatedNote = Note(
        id: localNote.id,
        title: serverData['title'],
        content: serverData['content'],
        remoteId: serverData['remote_id'],
        isDeleted: serverData['is_deleted'],
        createdAt: localNote.createdAt, /// Keep original creation time
        updatedAt: serverData['updated_at'], /// Use server's updated time
      );

      /// Attach the category to the note
      final int? remoteCategoryId = serverData['remote_category_id'];
      if (remoteCategoryId != null) {
        Category? localCategory = await _categoryLocalRepository.getCategoryByRemoteId(remoteCategoryId);
        localCategory ??= await _categoryLocalRepository.createCategory(
            name: serverData['remote_category_name'],
            remoteId: serverData['remote_category_id'],
            orderIndex: serverData['remote_category_order_index']
        );
        remoteUpdatedNote.categoryId = localCategory.id!;
      }

      /// Update the note in local database
      await _noteLocalRepository.updateNote(remoteUpdatedNote);
    } catch (error) {
      logger.e('Error handling newer server note: $error');
      rethrow;
    }
  }

  static Future<void> _notifyRemoteToDeleteNotes() async {
    try {
      final List<Note> deletedNotes = await _noteLocalRepository.getNotesMarkedForDeletion();
      logger.i('Found ${deletedNotes.length} notes marked for deletion to synchronize.');

      for (final note in deletedNotes) {
        if (note.remoteId != null) {
          try {
            final Response response = await _httpClient.delete(
              '$supabaseFunctionUrl/notes/${note.remoteId}',
              options: Options(
                headers: {
                  'Authorization': 'Bearer $supabaseServiceRoleKey',
                  'Content-Type': 'application/json',
                },
              ),
            );

            // Check for a success response from the server.
            if (response.data['message'] == 'NOTE_IS_DELETED_SUCCESSFULLY') {
              logger.i('Note with remote ID ${note.remoteId} successfully deleted from remote server. Deleting from local DB...');
              await _noteLocalRepository.deleteNote(note.id!);
            } else {
              logger.e('Failed to delete note with remote ID ${note.remoteId} from remote server. Server response: ${response.data}');
            }
          } catch (e) {
            logger.e('Error while trying to delete note with remote ID ${note.remoteId}: $e');
          }
        }
      }
    } catch (error) {
      logger.e('Error in _notifyRemoteToDeleteNotes: $error');
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
      await Future.wait([_synchronizeCategories(), _fetchNewCategoriesFromServer(), _synchronizeNotes()]);
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
