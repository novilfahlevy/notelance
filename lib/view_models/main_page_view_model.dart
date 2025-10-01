import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:notelance/config.dart';
import 'package:notelance/helpers.dart';
import 'package:notelance/local_database.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/pages/categories_page.dart';
import 'package:notelance/pages/note_editor_page.dart';
import 'package:notelance/pages/search_page.dart';
import 'package:notelance/repositories/category_local_repository.dart';
import 'package:notelance/repositories/note_local_repository.dart';
import 'package:notelance/synchronization.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class MainPageViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  Logger get logger => _logger;

  final NoteLocalRepository _noteRepository = NoteLocalRepository();
  final CategoryLocalRepository _categoryRepository = CategoryLocalRepository();

  List<Category> categories = [];

  /// Notes mapped by its category.
  /// The 'Umum' category has the '0' key.
  Map<int, List<Note>> mappedNotes = {};

  /// To show the loading indicator when syncing.
  bool isSyncing = false;

  /// The status of the sync operation
  bool? isSyncSuccess;

  /// This key is used to uniquely identify NotesPage widgets.
  /// So if this key is changed, those notes pages would be re-rendered.
  late String randomKey;

  MainPageViewModel() :
        randomKey = DateTime.now().toUtc().microsecondsSinceEpoch.toString();

  Future<void> spawnSynchronizationIsolate() async {
    if (await hasInternetConnection()) {
      isSyncing = true;
      isSyncSuccess = null; // Reset sync status

      final receivePort = ReceivePort();

      try {
        final databasePath = await LocalDatabase.instance.getDatabasePath();
        await Isolate.spawn<SynchronizationIsolateMessage>(
            isolateEntry,
            SynchronizationIsolateMessage(
                supabaseFunctionUrl: Config.instance.supabaseFunctionUrl,
                supabaseServiceRoleKey: Config.instance.supabaseServiceRoleKey,
                sendPort: receivePort.sendPort,
                rootIsolateToken: RootIsolateToken.instance!,
                databasePath: databasePath,
                isSentryEnabled: Config.instance.isSentryEnabled,
                sentryDsn: Config.instance.sentryDsn
            )
        );

        // Listen for the result
        receivePort.listen((message) {
          if (message is Map<String, dynamic>) {
            if (message['status'] == 'success') {
              _logger.i('Synchronization completed successfully');

              loadCategories().then((_) => loadNotes());

              randomKey = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
              isSyncing = false;
              isSyncSuccess = true;
            } else if (message['status'] == 'error') {
              _logger.e('Synchronization failed: ${message['error']}');

              isSyncing = false;
              isSyncSuccess = false;
            }
          }
          receivePort.close();
        });
      } catch (error) {
        _logger.e('Error spawning isolate: $error');

        isSyncing = false;
        isSyncSuccess = false;

        receivePort.close();
      }
    } else {
      isSyncing = false;
      isSyncSuccess = false;
    }

    notifyListeners();
  }

  Future<void> loadCategories() async {
    try {
      final categories = await _categoryRepository.get();
      this.categories = categories;
      notifyListeners();
    } catch (e) {
      _logger.e(e.toString());
    }
  }

  Future<void> loadNotes() async {
    try {
      final Map<int, List<Note>> mappedNotes = {};

      mappedNotes[0] = await _noteRepository.getUncategorized();

      for (final Category category in categories) {
        final List<Note> notes = await _noteRepository.getByCategory(category.id!);
        mappedNotes[category.id!] = notes;
      }

      this.mappedNotes = mappedNotes;

      notifyListeners();
    } catch (e) {
      _logger.e('Error loading notes: ${e.toString()}');
    }
  }

  void reloadPage({
    bool categories = true,
    bool notes = true,
    bool sync = true
  }) {
    if (categories) {
      loadCategories().then((_) {
        if (notes) loadNotes();
      });
    } else {
      if (notes) loadNotes();
    }

    if (sync) spawnSynchronizationIsolate();
  }
}