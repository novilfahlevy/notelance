import 'dart:isolate';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:notelance/responses/synchronization_response.dart';
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
  final String? sentryDsn;
  final bool isSentryEnabled;

  SynchronizationIsolateMessage({
    required this.supabaseFunctionUrl,
    required this.supabaseServiceRoleKey,
    required this.sendPort,
    required this.rootIsolateToken,
    required this.databasePath,
    this.sentryDsn,
    this.isSentryEnabled = false
  });
}

void isolateEntry(SynchronizationIsolateMessage message) async {
  try {
    BackgroundIsolateBinaryMessenger.ensureInitialized(message.rootIsolateToken);

    /// Re-initialize SQFLite
    await LocalDatabaseService.instance.initialize(
        successMessage: 'Database successfully initialized in the synchronization worker.'
    );

    final bool isSentryEnabled = message.isSentryEnabled && message.sentryDsn != null;
    if (isSentryEnabled) {
      await Sentry.init(
        (options) {
          options.dsn = message.sentryDsn;
          options.sendDefaultPii = true;
        }
      );
    }

    /// Run synchronization
    Synchronization.isSentryEnabled = isSentryEnabled;
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
  static Options get _httpOptions =>
      Options(
        headers: {
          'Authorization': 'Bearer $supabaseServiceRoleKey',
          'Content-Type': 'application/json',
        },
      );

  static bool isSentryEnabled = false; // The default is false

  static Future<void> _synchronizeLocalCategoriesWithRemote() async {
    try {
      // Get all local categories
      final List<Category> localCategories = await _categoryLocalRepository.getWithTrashed();

      // Prepare categories data for sync endpoint
      final List<Map<String, dynamic>> categoriesPayload = localCategories
          .map((category) {
            return {
              'client_id': category.id,
              'remote_id': category.remoteId,
              'name': category.name,
              'order_index': category.orderIndex,
              'is_deleted': category.isDeleted,
              'created_at': category.createdAt,
              'updated_at': category.updatedAt,
            };
          })
          .toList();

      // Make sync request
      final Response httpResponse = await _httpClient.post(
        '$supabaseFunctionUrl/categories/sync',
        data: { 'categories': categoriesPayload },
        options: _httpOptions,
      );
      final response = CategoriesSyncResponse.fromJson(httpResponse.data);

      if (response.state == 'CATEGORIES_HAVE_SYNCED') {
        final List<dynamic> categoryResponses = response.categories;

        for (final categoryResponse in categoryResponses) {
          final Map<String, dynamic> responseData = categoryResponse as Map<String, dynamic>;
          final int localCategoryId = responseData['client_id'];
          final Category localCategory = localCategories.firstWhere(
                (cat) => cat.id == localCategoryId,
                orElse: () => throw Exception('Local category not found'),
          );
          await _handleCategoryResponse(localCategory, responseData);
        }
      } else if (response.state == 'CATEGORIES_SYNC_IS_FAILED') {
        throw Exception('Local categories sync failed: ${response.errorMessage}');
      } else {
        throw Exception('Unexpected response state: ${response.state}');
      }
    } catch (exception, stackTrace) {
      logger.e('Exception synchronizing local categories: $exception');
      if (isSentryEnabled) await Sentry.captureException(exception, stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<void> _handleCategoryResponse(Category localCategory, Map<String, dynamic> responseData) async {
    try {
      switch (responseData['state']) {
        case 'CATEGORY_ID_IS_NOT_PROVIDED':
          // Category was created on remote, update local with remote_id
          final categoryResponse = RemoteCategoryIdIsNotFoundResponse.fromJson(responseData);
          if (categoryResponse.remoteId != null) {
            await _categoryLocalRepository.update(
              localCategory.id!,
              remoteId: int.parse(categoryResponse.remoteId.toString())
            );
            logger.i('Updated local category ${localCategory.name} with remote_id: ${categoryResponse.remoteId}');
          } else {
            logger.e('Failed to create category ${localCategory.name} on remote: ${categoryResponse.message}');
          }
        break;

        case 'CATEGORY_IN_THE_REMOTE_IS_NEWER':
          // Update local category with remote data
          final categoryResponse = RemoteCategoryIsNewerResponse.fromJson(responseData);
          await _categoryLocalRepository.update(
            localCategory.id!,
            name: categoryResponse.name,
            orderIndex: categoryResponse.orderIndex,
            updatedAt: categoryResponse.updatedAt
          );
          logger.i('Updated local category ${localCategory.name} with newer remote data');
        break;

        case 'CATEGORY_IN_THE_REMOTE_IS_DEPRECATED':
          final categoryResponse = RemoteCategoryIsDeprecatedResponse.fromJson(responseData);
          if (categoryResponse.message != null && categoryResponse.message!.contains('updated')) {
            logger.i('Successfully updated remote category for ${localCategory.name}');
          } else {
            logger.e('Failed to update remote category for ${localCategory.name}.');
          }
        break;

        case 'CATEGORY_ID_IS_NOT_VALID':
          final categoryResponse = RemoteCategoryIdIsNotValidResponse.fromJson(responseData);
          logger.e('Invalid remote_id for category ${localCategory.name}: ${categoryResponse.remoteId}');
        break;

        case 'AN_ERROR_OCCURED_IN_THIS_CATEGORY':
          final categoryResponse = ErrorIsOccurredCategoryResponse.fromJson(responseData);
          logger.e('Error occurred for category ${localCategory.name}: ${categoryResponse.errorMessage}');
        break;

        case 'CATEGORY_IS_NOT_FOUND_IN_THE_REMOTE':
          logger.i('Category ${localCategory.name} is not found on remote, it may have been deleted remotely.');
        break;

        case 'CATEGORY_IN_THE_REMOTE_IS_THE_SAME':
          logger.d('Category ${localCategory.name} is in sync');
        break;

        default:
          logger.w('Unknown sync state for category ${localCategory.name}: ${responseData['state']}');
      }
    } catch (exception, stackTrace) {
      logger.e('Failed handling remote categories response for ${localCategory.name}: $exception');
      if (isSentryEnabled) await Sentry.captureException(exception, stackTrace: stackTrace);
    }
  }

  static Future<void> _fetchNewCategoriesFromRemote() async {
    try {
      final Response response = await _httpClient.get(
        '$supabaseFunctionUrl/categories',
        options: _httpOptions,
      );

      if (response.data['message'] == 'CATEGORIES_IS_FETCHED_SUCCESSFULLY') {
        final List<dynamic> remoteCategories = response.data['categories'] as List<dynamic>;

        for (final remoteCategoryData in remoteCategories) {
          final int remoteId = remoteCategoryData['remote_id'] ?? remoteCategoryData['id'];
          final Category? existingCategory = await _categoryLocalRepository.getByRemoteId(remoteId);

          if (existingCategory == null) {
            // Create new category locally
            await _categoryLocalRepository.create(
              name: remoteCategoryData['name'],
              orderIndex: remoteCategoryData['order_index'],
              remoteId: remoteId,
            );
            logger.i('Created new local category from remote: ${remoteCategoryData['name']}');
          }
        }
      }
    } catch (exception, stackTrace) {
      logger.e('Failed fetching new categories from remote: $exception');
      if (isSentryEnabled) await Sentry.captureException(exception, stackTrace: stackTrace);
      // Don't rethrow here as this is a supplementary operation
    }
  }

  static Future<void> _synchronizeLocalNotesWithRemote() async {
    try {
      // Get all local notes that need syncing (both deleted and active)
      final List<Note> localNotes = await _noteLocalRepository.getWithTrashed();

      // Prepare notes data for sync endpoint
      final List<Map<String, dynamic>> notesPayload = localNotes.map((note) {
        return {
          'client_id': note.id,
          'remote_id': note.remoteId,
          'title': note.title,
          'content': note.content,
          'category_id': note.categoryId,
          'is_deleted': note.isDeleted,
          'created_at': _ensureUTCFormat(note.createdAt!),
          'updated_at': _ensureUTCFormat(note.updatedAt!),
        };
      }).toList();

      // Make sync request
      final Response response = await _httpClient.post(
        '$supabaseFunctionUrl/notes/sync',
        data: { 'notes': notesPayload },
        options: _httpOptions,
      );

      if (response.data['state'] == 'NOTES_HAVE_SYNCED') {
        final NotesResponseSucceed successResponse = NotesResponseSucceed.fromJson(response.data);

        for (final noteResponse in successResponse.notes) {
          final Map<String, dynamic> noteData = noteResponse as Map<String, dynamic>;
          final int localNoteId = noteData['client_id'];
          final Note localNote = localNotes.firstWhere(
                (localNote) => localNote.id == localNoteId,
                orElse: () => throw Exception('Local note not found'),
          );
          await _handleNoteResponse(localNote, noteData);
        }
      } else if (response.data['state'] == 'NOTES_SYNC_IS_FAILED') {
        throw Exception('Notes sync failed: ${response.data['errorMessage']}');
      } else {
        throw Exception('Unexpected response state: ${response.data['state']}');
      }
    } catch (exception, stackTrace) {
      logger.e('Failed synchronizing local notes: $exception');
      if (isSentryEnabled) await Sentry.captureException(exception, stackTrace: stackTrace);
      // Don't rethrow here as this is a supplementary operation
    }
  }

  static Future<void> _handleNoteResponse(Note localNote, Map<String, dynamic> responseData) async {
    try {
      switch (responseData['state']) {
        case 'NOTE_ID_IS_NOT_PROVIDED':
          final RemoteNoteIdIsNotProvidedResponse response = RemoteNoteIdIsNotProvidedResponse.fromJson(responseData);

          // Note was created on remote, update local with remote_id
          if (response.remoteId != null) {
            await _noteLocalRepository.update(localNote.id!,
              remoteId: response.remoteId,
              updatedAt: localNote.updatedAt!
            );
            logger.i('Updated local note ${localNote.title} with remote_id: ${response.remoteId}');
          } else {
            logger.e('Failed to create note ${localNote.title} on remote: ${response.message}');
          }
        break;

        case 'NOTE_IN_THE_REMOTE_IS_NEWER':
          final RemoteNoteIsNewerResponse response = RemoteNoteIsNewerResponse.fromJson(responseData);
          int? categoryId;

          // Handle category update
          final int? remoteCategoryId = response.categoryId;
          if (remoteCategoryId != null) {
            final Category? localCategory = await _categoryLocalRepository.getByRemoteId(remoteCategoryId);
            if (localCategory != null) categoryId = localCategory.id;
          }

          await _noteLocalRepository.update(localNote.id!,
            title: response.title,
            content: response.content,
            categoryId: categoryId,
            remoteId: response.remoteId,
            isDeleted: response.isDeleted,
            updatedAt: response.updatedAt,
          );

          logger.i('Updated local note ${localNote.title} with newer remote data');
        break;

        case 'NOTE_IN_THE_REMOTE_IS_DEPRECATED':
          final RemoteNoteIsDeprecatedResponse response = RemoteNoteIsDeprecatedResponse.fromJson(responseData);
          if (response.message != null && response.message!.contains('updated')) {
            logger.i('Successfully updated remote note for ${localNote.title}');
          } else {
            logger.e('Failed to update remote note for ${localNote.title}: ${response.message}');
          }
        break;

        case 'NOTE_ID_IS_NOT_VALID':
          final RemoteNoteIdIsNotValidResponse response = RemoteNoteIdIsNotValidResponse.fromJson(responseData);
          logger.e('Invalid remote_id for note ${localNote.title}: ${response.remoteId}');
        break;

        case 'AN_ERROR_OCCURRED_IN_THIS_NOTE':
          final ErrorIsOccurredNoteResponse response = ErrorIsOccurredNoteResponse.fromJson(responseData);
          logger.e('Error occurred for note ${localNote.title}: ${response.errorMessage}');
        break;

        case 'NOTE_IS_NOT_FOUND_IN_THE_REMOTE':
          final NoteIsNotFoundInRemoteResponse response = NoteIsNotFoundInRemoteResponse.fromJson(responseData);
          await _noteLocalRepository.delete(response.clientId);
          logger.i('Note ${response.title} not found on remote, it may have been deleted remotely. So it has deleted too in locally.');
        break;

        case 'NOTE_IN_THE_REMOTE_IS_THE_SAME':
          final NotesHaveSameTimesResponse response = NotesHaveSameTimesResponse.fromJson(responseData);
          logger.i('Note with Local ID: ${response.clientId} and Remote ID: ${response.remoteId} is still the same.');
        break;

        default:
          logger.w('Unknown sync state for note ${localNote.title}: ${responseData['state']}');
      }
    } catch (exception, stackTrace) {
      logger.e('Failed handling note response for ${localNote.title}: $exception');
      if (isSentryEnabled) await Sentry.captureException(exception, stackTrace: stackTrace);
      // Don't rethrow here as this is a supplementary operation
    }
  }

  static Future<void> _fetchNewNotesFromRemote() async {
    try {
      String url = '$supabaseFunctionUrl/notes';

      final List<Note> notesWithRemoteId = await _noteLocalRepository.getWithRemoteId();
      final List<int> remoteIds = notesWithRemoteId.map((Note note) => note.remoteId!).toList();

      if (remoteIds.isNotEmpty) {
        url += '?excepts=${remoteIds.join(',')}';
      }

      final Response response = await _httpClient.get(url, options: _httpOptions);

      if (response.statusCode == 200) {
        final List<dynamic> allRemoteNotesData = response.data['notes'] as List<dynamic>;

        for (final remoteNoteRaw in allRemoteNotesData) {
          final FetchNoteResponse remoteNoteData = FetchNoteResponse.fromJson(remoteNoteRaw);
          final int currentRemoteNoteId = remoteNoteData.remoteId;

          // Check if a local note with this remote_id exists
          if (await _noteLocalRepository.checkNoteIsNotExistedByRemoteId(currentRemoteNoteId)) {
            // Parse timestamps from remote
            final String createdAtStringFromRemote = remoteNoteData.createdAt;
            final String updatedAtStringFromRemote = remoteNoteData.updatedAt;

            final DateTime createdAtUtc = DateTime.parse(createdAtStringFromRemote);
            final DateTime updatedAtUtc = DateTime.parse(updatedAtStringFromRemote);

            int? categoryId;

            // Attach the category to the note
            final int? remoteCategoryId = remoteNoteData.remoteCategoryId;
            if (remoteCategoryId != null) {
              Category? localCategory = await _categoryLocalRepository.getByRemoteId(remoteCategoryId);
              localCategory ??= await _categoryLocalRepository.create(
                  name: remoteNoteData.remoteCategoryName!,
                  remoteId: remoteCategoryId,
                  orderIndex: remoteNoteData.remoteCategoryOrderIndex
              );
              categoryId = localCategory.id;
            }

            // Insert the remote note to the local database
            await _noteLocalRepository.create(
                title: remoteNoteData.title,
                content: remoteNoteData.content,
                categoryId: categoryId,
                remoteId: currentRemoteNoteId,
                createdAt: createdAtUtc.toIso8601String(),
                updatedAt: updatedAtUtc.toIso8601String(),
                isDeleted: remoteNoteData.isDeleted,
            );
            logger.i('Created new local note from remote: ${remoteNoteData.title}');
          }
        }
      } else {
        logger.e("Failed to fetch remote notes. Status: ${response.statusCode}, Data: ${response.data}");
      }
    } catch (exception, stackTrace) {
      logger.e("Failed fetching new remote notes: $exception");
      if (isSentryEnabled) await Sentry.captureException(exception, stackTrace: stackTrace);
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
    } catch (exception) {
      logger.e('Failed parsing timestamp: $timestamp, exception: $exception');
      // Return current UTC time as fallback
      return DateTime.now().toUtc().toIso8601String();
    }
  }

  static Future<Map<String, dynamic>> run() async {
    try {
      await _synchronizeLocalCategoriesWithRemote();
      await _fetchNewCategoriesFromRemote();
      await _synchronizeLocalNotesWithRemote();
      await _fetchNewNotesFromRemote();

      return {
        'categoriesSync': 'success',
        'notesSync': 'success',
        'timestamp': DateTime.now().toUtc().toIso8601String()
      };
    } catch (exception, stackTrace) {
      if (isSentryEnabled) await Sentry.captureException(exception, stackTrace: stackTrace);
      return {
        'error': exception.toString(),
        'timestamp': DateTime.now().toUtc().toIso8601String()
      };
    }
  }
}