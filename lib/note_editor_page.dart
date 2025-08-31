import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:delta_to_html/delta_to_html.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/notifiers/categories_notifier.dart';
import 'package:notelance/local_database_service.dart';
import 'package:notelance/categories_dialog.dart';
import 'package:notelance/delete_note_dialog.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key});

  static const String path = '/note_editor_page';

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  int? _noteId;
  bool _isInitialized = false;
  final LocalDatabaseService _databaseService = LocalDatabaseService.instance;

  final TextEditingController _titleController = TextEditingController();
  final QuillController _contentController = QuillController.basic();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _editorFocusNode = FocusNode();

  Category? _category;
  List<Category> _categories = [];
  String _pendingNewCategoryName = ''; // Store pending new category name

  String _initialTitle = '';
  int _initialContentDeltaHashCode = 0;

  bool get _hasUnsavedChanges {
    if (!_isInitialized) return false;

    final String title = _titleController.text.trim();
    final contentDeltaHashCode = _contentController.document.toDelta().hashCode;
    return _initialTitle != title ||
        _initialContentDeltaHashCode != contentDeltaHashCode;
  }

  bool _isSaving = false;
  bool _isLoading = true;
  bool _isDeleting = false;

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
        _noteId = arguments.id;
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

  Future<void> _initialize() async {
    if (_isInitialized) return;

    setState(() => _isLoading = true);

    try {
      await _loadCategories();
      if (_noteId != null) await _loadNote();

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

  Future<void> _loadNote() async {
    if (!_databaseService.isInitialized || _noteId == null) return;

    try {
      final note = await _databaseService.getNoteById(_noteId!);

      if (note == null) {
        _showErrorSnackBar('Catatan tidak ditemukan');
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (!mounted) return;

      // Find category
      _category = _categories.firstWhere(
            (cat) => cat.id == note.categoryId,
        orElse: () => _categories.first, // Should be a safe default
      );

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

  Future<void> _loadCategories() async {
    if (!_databaseService.isInitialized) return;

    try {
      final categories = await _databaseService.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;
      });
    } catch (e) {
      logger.e('Error loading categories: $e');
    }
  }

  Future<void> _showCategoriesDialog() async {
    final result = await CategoriesDialog.show(
      context: context,
      categories: _categories,
      selectedCategory: _category,
    );

    if (result != null) {
      if (result.isNewCategory) {
        // Store the new category name to be created during save
        setState(() {
          _category = null;
          _pendingNewCategoryName = result.newCategoryName!;
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

  Future<bool> _showDeleteConfirmation() async {
    if (_noteId == null) return false; // Can't delete unsaved note

    return await DeleteNoteDialog.show(
      context: context,
      noteTitle: _titleController.text.trim(),
    );
  }

  Future<void> _deleteNote() async {
    if (_noteId == null || _isDeleting) return;

    final shouldDelete = await _showDeleteConfirmation();
    if (!shouldDelete) return;

    setState(() => _isDeleting = true);

    try {
      await _databaseService.deleteNote(_noteId!);

      logger.d('Note deleted successfully with ID: $_noteId');
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

  Future<int> _createNewNote(Note note) async {
    try {
      final savedNoteId = await _databaseService.createNote(note);
      setState(() => _noteId = savedNoteId);
      logger.d('New note saved with ID: $savedNoteId');
      return savedNoteId;
    } catch (e) {
      logger.e('Error in _createNewNote method: $e');
      rethrow;
    }
  }

  Future<void> _updateNote(Note note) async {
    try {
      await _databaseService.updateNote(note);
      logger.d('Note updated with ID: $_noteId');
    } catch (e) {
      logger.e('Error in _updateNote method: $e');
      rethrow;
    }
  }

  Future<String> _getCreatedAtOfExistingNote() async {
    try {
      final existingNote = await _databaseService.getNoteById(_noteId!);

      if (existingNote != null) {
        return existingNote.createdAt!;
      }

      throw Exception('Catatan tidak ditemukan');
    } catch (e) {
      logger.e('Error in _getCreatedAtOfExistingNote: $e');
      rethrow;
    }
  }

  Future<Category> _createNewCategory(String categoryName) async {
    try {
      final newCategory = await _databaseService.createCategory(categoryName);

      // Reload categories to include the new one
      await _loadCategories();

      if (mounted) {
        // Reload categories in the main page's appbar
        context.read<CategoriesNotifier>().reloadCategories();
      }

      logger.d('Category created with ID: ${newCategory.id}');

      return newCategory;
    } catch (e) {
      logger.e('Error in _createNewCategory method: $e');
      rethrow;
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();

    if (title.isEmpty) {
      _showErrorSnackBar('Judul catatan tidak boleh kosong');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final Delta delta = _contentController.document.toDelta();
      final String now = DateTime.now().toIso8601String();
      Category? attachedCategory = _category;

      // Handle new category creation if pending
      if (attachedCategory == null && _pendingNewCategoryName.isNotEmpty) {
        attachedCategory = await _createNewCategory(_pendingNewCategoryName);
      }

      if (attachedCategory == null) {
        _showErrorSnackBar('Kategori belum dipilih atau dibuat.');
        setState(() => _isSaving = false);
        return;
      }

      final bool isNewNote = _noteId == null;

      if (isNewNote) {
        // For new notes, create the complete Note object
        final note = Note(
          title: title,
          content: DeltaToHTML.encodeJson(delta.toJson()),
          categoryId: attachedCategory.id!,
          createdAt: now,
          updatedAt: now,
        );
        await _createNewNote(note);
      } else {
        // For existing notes, create Note object with existing created_at
        final createdAt = await _getCreatedAtOfExistingNote();
        final note = Note(
          id: _noteId,
          title: title,
          content: DeltaToHTML.encodeJson(delta.toJson()),
          categoryId: attachedCategory.id!,
          createdAt: createdAt,
          updatedAt: now,
        );
        await _updateNote(note);
      }

      // Refresh all states with the new/updated category
      setState(() {
        _initialTitle = title;
        _initialContentDeltaHashCode = delta.hashCode;
        _category = attachedCategory;
        _pendingNewCategoryName = ''; // Clear pending category name
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

  Future<bool> _showExitConfirmation() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const BeveledRectangleBorder(),
        title: const Text(
          'Batalkan penulisan?',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text('Perubahan akan hilang jika belum disimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tetap menulis'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleBackPressed() async {
    final shouldPop = await _showExitConfirmation();
    if (shouldPop && mounted) {
      Navigator.of(context).pop();
    }
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
    return (_category != null || _pendingNewCategoryName.isNotEmpty)
        ? Colors.blueAccent
        : Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Memuat...')),
        body: const Center(child: CircularProgressIndicator()),
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
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackPressed,
          ),
          actions: [
            // Only show delete button for existing notes
            if (_noteId != null)
              TextButton(
                onPressed: _isDeleting ? null : _deleteNote,
                child: Text(
                  _isDeleting ? 'Menghapus...' : 'Hapus',
                  style: TextStyle(
                    color: _isDeleting ? Colors.grey : Colors.redAccent,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            TextButton(
              onPressed: _showCategoriesDialog,
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
                  color: (_isSaving || _isDeleting) ? Colors.grey : Colors.orangeAccent,
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
                decoration: const InputDecoration(
                  hintText: 'Judul catatan',
                  hintStyle: TextStyle(fontSize: 18, color: Colors.grey),
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
                      const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color: Colors.black,
                      ),
                      HorizontalSpacing.zero,
                      VerticalSpacing.zero,
                      VerticalSpacing.zero,
                      null,
                    ),
                    placeHolder: DefaultTextBlockStyle(
                      const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
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
            QuillSimpleToolbar(
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
            )
          ],
        ),
      ),
    );
  }
}