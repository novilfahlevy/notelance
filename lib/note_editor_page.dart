import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:delta_to_html/delta_to_html.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:logger/logger.dart';
import 'package:notelance/categories_dialog.dart';
import 'package:notelance/delete_note_dialog.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/notifiers/categories_notifier.dart';
import 'package:notelance/repositories/category_local_repository.dart';
import 'package:notelance/repositories/note_local_repository.dart'; // Added
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

var logger = Logger();

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key});

  static const String path = '/note_editor_page';

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  // ===== PROPERTIES =====
  // Core properties
  Note? _note;
  bool _isInitialized = false;
  final NoteLocalRepository _noteRepository = NoteLocalRepository(); // Changed
  final CategoryLocalRepository _categoryRepository = CategoryLocalRepository();

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final QuillController _contentController = QuillController.basic();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _editorFocusNode = FocusNode();

  // Category management
  Category? _category;
  List<Category> _categories = [];
  String _pendingNewCategoryName = ''; // Store pending new category name

  // Change tracking
  String _initialTitle = '';
  int _initialContentDeltaHashCode = 0;

  // Loading states
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isDeleting = false;

  // ===== COMPUTED PROPERTIES =====
  bool get _hasUnsavedChanges {
    if (!_isInitialized) return false;

    final String title = _titleController.text.trim();
    final contentDeltaHashCode = _contentController.document.toDelta().hashCode;
    return _initialTitle != title ||
        _initialContentDeltaHashCode != contentDeltaHashCode;
  }

  String get _categoryDisplayText {
    if (_category != null) {
      return _category!.name;
    } else if (_pendingNewCategoryName.isNotEmpty) {
      return "Baru: $_pendingNewCategoryName";
    } else {
      return 'Pilih Kategori';
    }
  }

  Color get _categoryDisplayColor {
    final theme = Theme.of(context);
    if (_category != null || _pendingNewCategoryName.isNotEmpty) {
      return theme.colorScheme.primary; // Use theme's primary color
    } else {
      return theme.colorScheme.onSurface.withOpacity(0.6); // Use theme's muted text color
    }
  }

  // ===== LIFECYCLE METHODS =====
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is Note) {
        setState(() {
          _note = arguments;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  // ===== INITIALIZATION METHODS =====
  Future<void> _initialize() async {
    if (_isInitialized) return;

    setState(() => _isLoading = true);

    try {
      await _loadCategories();
      if (_note != null) await _loadNote();

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Error initializing note editor: $e');
      setState(() => _isLoading = false);
      _showErrorSnackBar('Gagal memuat data: ${e.toString()}');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryRepository.get();

      if (!mounted) return;

      setState(() => _categories = categories);
    } catch (e) {
      logger.e('Error loading categories: $e');
    }
  }

  Future<void> _loadNote() async {
    // Changed: Removed _databaseService.isInitialized check
    if (_note == null || _note!.id == null) return;

    try {
      // Changed: Used _noteRepository
      final note = await _noteRepository.getById(_note!.id!);

      if (note == null) {
        _showErrorSnackBar('Catatan tidak ditemukan');
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (!mounted) return;

      // Update the stored note object with fresh data
      setState(() {
        _note = note;
      });

      // Find the note's category
      if (note.categoryId != null) {
        _category = _categories.firstWhere((cat) => cat.id == note.categoryId);
      }

      _titleController.text = note.title;
      final initialContentDeltaHashCode = _setInitialContent(note.content!);

      setState(() {
        _initialTitle = note.title;
        _initialContentDeltaHashCode = initialContentDeltaHashCode;
      });
    } catch (e) {
      logger.e('Error loading note: $e');
      _showErrorSnackBar('Gagal memuat catatan');
    }
  }

  int _setInitialContent(String content) {
    try {
      final delta = HtmlToDelta().convert(content);
      _contentController.document = Document.fromDelta(delta);
      return delta.hashCode;
    } catch (e) {
      logger.e('Error setting initial content: $e');
      return 0;
    }
  }

  // ===== CATEGORY MANAGEMENT METHODS =====
  Future<void> _showCategoriesDialog({String? newCategoryNameInputError}) async {
    final result = await CategoriesDialog.show(
      context: context,
      categories: _categories,
      selectedCategory: _category,
      newCategoryNameInputError: newCategoryNameInputError,
    );

    if (result != null) {
      if (result.isNewCategory) {
        final categoryName = result.newCategoryName?.trim();
        final validationError = await _validateNewCategoryName(categoryName);

        if (validationError != null) {
          // Re-show dialog with error
          if (mounted) _showCategoriesDialog(newCategoryNameInputError: validationError);
          return;
        }

        // Store the new category name to be created during save
        setState(() {
          _category = null;
          _pendingNewCategoryName = categoryName!;
        });
      } else {
        // Use existing category
        setState(() {
          _category = result.existingCategory;
          _pendingNewCategoryName = '';
        });
      }
    }
  }

  Future<String?> _validateNewCategoryName(String? name) async {
    if (name == null || name.trim().isEmpty) {
      return 'Nama kategori tidak boleh kosong.';
    }

    try {
      final existingCategory = await _categoryRepository.getByName(name.trim());
      if (existingCategory != null) {
        return 'Kategori "${name.trim()}" sudah ada.';
      }
    } catch (e) {
      logger.e('Error validating category name: $e');
      // Fall back to local validation if database check fails
      final exists = _categories.any((cat) =>
      cat.name.toLowerCase() == name.trim().toLowerCase());
      if (exists) {
        return 'Kategori "${name.trim()}" sudah ada.';
      }
    }

    return null;
  }

  Future<Category> _createNewCategory(String categoryName) async {
    try {
      // Create category using the repository
      final newCategory = await _categoryRepository.create(name: categoryName.trim());

      // Reload categories in the categories selector
      await _loadCategories();

      // Reload categories in the main page's appbar
      if (mounted) context.read<CategoriesNotifier>().reloadCategories();

      logger.d('Category created with ID: ${newCategory.id}');

      // Then save the category in the remote database
      await _saveCategoryInRemoteDatabase(newCategory);

      return newCategory;
    } catch (e) {
      logger.e('Error in _createNewCategory method: $e');
      rethrow;
    }
  }

  // ===== SAVE METHODS =====
  Future<void> _save() async {
    if (_isSaving) return;

    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Judul catatan tidak boleh kosong');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Handle new category creation if pending
      Category? attachedCategory = _category;
      if (attachedCategory == null && _pendingNewCategoryName.isNotEmpty) {
        // Validate again before actual creation, as a final check
        final validationError = await _validateNewCategoryName(_pendingNewCategoryName);
        if (validationError != null) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }
        attachedCategory = await _createNewCategory(_pendingNewCategoryName);
      }

      final String title = _titleController.text.trim();
      final Delta delta = _contentController.document.toDelta();
      final String now = DateTime.now().toUtc().toIso8601String();
      final bool isNewNote = _note == null || _note!.id == null;

      if (isNewNote) {
        // Create new note object
        setState(() {
          _note = Note(
            title: title,
            content: DeltaToHTML.encodeJson(delta.toJson()),
            categoryId: attachedCategory?.id,
            createdAt: now,
            updatedAt: now,
          );
        });

        await _createNoteInLocalDatabase();
      } else {
        // Update existing note
        final existingCreatedAt = await _getCreatedAtOfExistingNote();
        setState(() {
          _note = _note!.copyWith(
            title: title,
            content: DeltaToHTML.encodeJson(delta.toJson()),
            categoryId: attachedCategory?.id,
            updatedAt: now,
            createdAt: existingCreatedAt,
          );
        });

        await _updateNoteInLocalDatabase();
      }

      // Save to remote database
      await _saveNoteInRemoteDatabase();

      // Update initial states
      setState(() {
        _initialTitle = title;
        _initialContentDeltaHashCode = delta.hashCode;
        _category = attachedCategory;
        _pendingNewCategoryName = '';
      });

      _showSuccessSnackBar(
        isNewNote ? 'Catatan berhasil disimpan' : 'Catatan berhasil diperbarui',
      );
    } catch (e) {
      logger.e('Error in _save method: $e');
      _showErrorSnackBar('Gagal menyimpan catatan: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ===== DELETE METHODS =====
  Future<void> _delete() async {
    if (_note == null || _note!.id == null || _isDeleting) return;

    final bool shouldDelete = await _showDeleteConfirmation();
    if (!shouldDelete) return;

    setState(() => _isDeleting = true);

    try {
      // Changed: Used _noteRepository
      await _noteRepository.delete(_note!.id!);
      await _deleteNoteInRemoteDatabase();

      logger.d('Note deleted successfully with ID: ${_note!.id}');
      _showSuccessSnackBar('Catatan berhasil dihapus');

      // Wait a moment for the snackbar to show, then navigate back
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate deletion
      }
    } catch (e) {
      logger.e('Error deleting note: $e');
      _showErrorSnackBar('Gagal menghapus catatan: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  // ===== LOCAL DATABASE METHODS =====
  Future<void> _createNoteInLocalDatabase() async {
    if (_note == null) {
      throw Exception('Note is null, cannot create in database');
    }

    try {
      // Changed: Used _noteRepository
      final Note createdNote = await _noteRepository.create(
        title: _note!.title,
        content: _note!.content!,
        categoryId: _note!.categoryId,
        remoteId: _note!.remoteId
      );
      setState(() {
        _note = _note!.copyWith(id: createdNote.id);
      });
      logger.d('New note saved with ID: ${createdNote.id}');
    } catch (e) {
      logger.e('Error creating note in local database: $e');
      rethrow;
    }
  }

  Future<void> _updateNoteInLocalDatabase() async {
    if (_note == null || _note!.id == null) {
      throw Exception('Note or note ID is null, cannot update in database');
    }

    try {
      // Changed: Used _noteRepository
      await _noteRepository.update(_note!.id!,
          title: _note!.title,
          content: _note!.content!,
          categoryId: _note!.categoryId,
          remoteId: _note!.remoteId,
          updatedAt: DateTime.now().toUtc().toIso8601String()
      );
      logger.d('Note updated with ID: ${_note!.id}');
    } catch (e) {
      logger.e('Error updating note in local database: $e');
      rethrow;
    }
  }

  Future<String> _getCreatedAtOfExistingNote() async {
    try {
      if (_note?.createdAt != null) {
        return _note!.createdAt!;
      }

      // Changed: Used _noteRepository
      final existingNote = await _noteRepository.getById(_note!.id!);

      if (existingNote != null) {
        return existingNote.createdAt!;
      }

      throw Exception('Catatan tidak ditemukan');
    } catch (e) {
      logger.e('Error in _getCreatedAtOfExistingNote: $e');
      rethrow;
    }
  }

  Future<void> _updateCategoryRemoteIdInLocalDatabase(Category category) async {
    try {
      await _categoryRepository.update(
          category.id!,
          name: category.name,
          remoteId: category.remoteId
      );
      logger.d('Category updated locally with ID: ${category.id}');
    } catch (e) {
      logger.e('Error in _updateCategoryRemoteIdInLocalDatabase method: $e');
    }
  }

  // ===== REMOTE DATABASE METHODS =====
  Future<void> _saveNoteInRemoteDatabase() async {
    if (_note == null) {
      logger.w("Cannot save note to remote database: Note is null");
      return;
    }

    if (!(await _isDeviceConnectedToInternet())) {
      logger.w("Can't save the note with id \"${_note!.id}\" to the remote database: No internet connection is available.");
      return;
    }

    try {
      final notePayload = _note!.toJson();

      if (_note?.categoryId != null) {
        final Category? category = await _categoryRepository.getById(_note!.categoryId!);
        if (category != null && category.remoteId != null) {
          notePayload['remote_category_id'] = category.remoteId;
        }
      }

      final FunctionResponse response = await Supabase.instance.client.functions.invoke(
        '${dotenv.env['SUPABASE_FUNCTION_NAME']!}/notes',
        method: HttpMethod.post,
        body: notePayload,
      );

      if (response.data['message'] == 'NOTE_IS_SUCCESSFULLY_SYNCED') {
        final int noteRemoteId = response.data['remote_id'];

        setState(() {
          _note = _note!.copyWith(remoteId: noteRemoteId);
        });

        // Update the remote ID in local database
        await _updateNoteInLocalDatabase();
      }
    } on Exception catch (e) {
      logger.e('Error saving note in remote database: $e');
    }
  }

  Future<void> _deleteNoteInRemoteDatabase() async {
    if (_note == null) {
      _showErrorSnackBar('Catatan tidak ditemukan.');
      return;
    }

    if (!(await _isDeviceConnectedToInternet())) {
      logger.w("Can't delete the note \"${_note?.title ?? ''}\" in the remote database: No internet connection is available.");
      return;
    }

    try {
      final FunctionResponse response = await Supabase.instance.client.functions.invoke(
          '${dotenv.env['SUPABASE_FUNCTION_NAME']!}/notes/${_note!.remoteId}',
          method: HttpMethod.delete
      );

      if (response.data['message'] == 'CATEGORY_IS_DELETED_SUCCESSFULLY') {
        if (mounted) {
          Navigator.of(context).pop();
        } else {
          _showErrorSnackBar('Catatan tidak ditemukan.');
        }
      }
    } on Exception catch (e) {
      logger.e('Error in _deleteNoteInRemoteDatabase method: $e');
    }
  }

  Future<void> _saveCategoryInRemoteDatabase(Category category) async {
    if (!(await _isDeviceConnectedToInternet())) {
      logger.w("Can't save the new category \"${category.name}\" to the remote database: No internet connection is available.");
      return;
    }

    try {
      final FunctionResponse response = await Supabase.instance.client.functions.invoke(
        '${dotenv.env['SUPABASE_FUNCTION_NAME']!}/categories',
        method: HttpMethod.post,
        body: category.toJson(),
      );

      if (response.data['message'] == 'CATEGORY_IS_CREATED_SUCCESSFULLY') {
        final int categoryRemoteId = response.data['remote_id'];

        // Update the remote id of the note in local database
        category.remoteId = categoryRemoteId;
        await _updateCategoryRemoteIdInLocalDatabase(category);
      }
    } on Exception catch (e) {
      logger.e('Error in _saveCategoryInRemoteDatabase method: $e');
    }
  }

  // ===== UTILITY METHODS =====
  Future<bool> _isDeviceConnectedToInternet() async {
    // --- VERCEL ---
    if (Platform.environment.containsKey('VERCEL')) {
      return true;
    }

    // --- WEB ---
    if (kIsWeb) {
      return true; // Or use a JavaScript interop to check window.navigator.onLine
    }

    // --- MOBILE / DESKTOP ---
    if (Platform.isAndroid || Platform.isIOS || Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult.contains(ConnectivityResult.mobile) ||
            connectivityResult.contains(ConnectivityResult.wifi) ||
            connectivityResult.contains(ConnectivityResult.ethernet) ||
            connectivityResult.contains(ConnectivityResult.vpn)) {
          return true;
        } else if (connectivityResult.contains(ConnectivityResult.none)) {
          return false;
        }
        return false;
      } catch (e) {
        logger.e('Error checking connectivity: $e');
        return false;
      }
    }
    logger.e('Connectivity check not supported on this platform or assuming offline.');
    return false;
  }

  // ===== UI HELPER METHODS =====
  Future<bool> _showDeleteConfirmation() async {
    if (_note == null || _note!.id == null) return false; // Can't delete unsaved note

    return await DeleteNoteDialog.show(
      context: context,
      noteTitle: _titleController.text.trim(),
    );
  }

  Future<bool> _askExitConfirmation() async {
    if (!_hasUnsavedChanges) return true;

    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const BeveledRectangleBorder(),
        backgroundColor: theme.colorScheme.surface, // Use theme surface color
        title: Text(
          'Batalkan penulisan?',
          style: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurface, // Use theme text color
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Perubahan akan hilang jika belum disimpan.',
          style: TextStyle(color: theme.colorScheme.onSurface), // Use theme text color
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Tetap menulis',
              style: TextStyle(color: theme.colorScheme.primary), // Use theme primary color
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Keluar',
              style: TextStyle(color: theme.colorScheme.error), // Use theme error color
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _handleBackPressed() async {
    final shouldPop = await _askExitConfirmation();
    if (shouldPop && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted || !context.mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white),),
        backgroundColor: theme.colorScheme.error, // Use theme error color
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.green, // Keep green for success
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===== BUILD METHOD =====
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Memuat...')),
        body: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary, // Use theme primary color
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPressed();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: theme.appBarTheme.iconTheme?.color ?? theme.colorScheme.onSurface,
            ),
            onPressed: _handleBackPressed,
          ),
          actions: [
            // Only show delete button for existing notes
            if (_note != null && _note!.id != null)
              TextButton(
                onPressed: _isDeleting ? null : _delete,
                child: Text(
                  _isDeleting ? 'Menghapus...' : 'Hapus',
                  style: TextStyle(
                    color: _isDeleting
                        ? theme.colorScheme.onSurface.withOpacity(0.3)
                        : theme.colorScheme.error, // Use theme error color
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            TextButton(
              onPressed: () => _showCategoriesDialog(),
              child: Text(
                _categoryDisplayText,
                style: TextStyle(
                  color: _categoryDisplayColor,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: (_isSaving || _isDeleting) ? null : _save,
              child: Text(
                'Simpan',
                style: TextStyle(
                  color: (_isSaving || _isDeleting)
                      ? theme.colorScheme.onSurface.withOpacity(0.3)
                      : theme.colorScheme.primary, // Use theme primary color
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Judul catatan',
                  hintStyle: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.6), // Use theme muted text color
                  ),
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface, // Use theme text color
                ),
                maxLines: 1,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _editorFocusNode.requestFocus(),
              ),
            ),
            Expanded(
              child: QuillEditor(
                controller: _contentController,
                scrollController: _scrollController,
                focusNode: _editorFocusNode,
                config: QuillEditorConfig(
                  placeholder: 'Tulis di sini...',
                  padding: const EdgeInsets.all(16),
                  expands: true,
                  autoFocus: false,
                  customStyles: DefaultStyles(
                    paragraph: DefaultTextBlockStyle(
                      TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color: theme.colorScheme.onSurface, // Use theme text color
                      ),
                      HorizontalSpacing.zero,
                      VerticalSpacing.zero,
                      VerticalSpacing.zero,
                      null,
                    ),
                    placeHolder: DefaultTextBlockStyle(
                      TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6), // Use theme muted text color
                        height: 1.4,
                      ),
                      HorizontalSpacing.zero,
                      VerticalSpacing.zero,
                      VerticalSpacing.zero,
                      null,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface, // Use theme surface color
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2), // Use theme outline color
                    width: 0.5,
                  ),
                ),
              ),
              child: QuillSimpleToolbar(
                controller: _contentController,
                config: const QuillSimpleToolbarConfig(
                  multiRowsDisplay: false,

                  // Active
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showListNumbers: true,
                  showListBullets: true,
                  showHeaderStyle: true,
                  showLink: true,
                  showListCheck: false,

                  // Unactive
                  showUndo: false,
                  showRedo: false,
                  showFontFamily: false,
                  showFontSize: false,
                  showStrikeThrough: false,
                  showInlineCode: false,
                  showColorButton: false,
                  showBackgroundColorButton: false,
                  showClearFormat: false,
                  showAlignmentButtons: false,
                  showDirection: false,
                  showCodeBlock: false,
                  showQuote: false,
                  showIndent: false,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                  showSmallButton: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
