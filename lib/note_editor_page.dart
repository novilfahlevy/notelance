import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:delta_to_html/delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/sqllite.dart';
import 'package:sqflite/sqflite.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key});

  static const String path = '/note_editor_page';

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  int? _noteId;
  bool _isInitialized = false;

  final TextEditingController _titleController = TextEditingController();
  final QuillController _contentController = QuillController.basic();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _editorFocusNode = FocusNode();

  Category? _category;
  List<Category> _categories = [];

  String _initialTitle = '';
  int _initialContentDeltaHashCode = 0;

  bool get _hasUnsavedChanges {
    if (!_isInitialized) return false;

    final String title = _titleController.text.trim();
    final contentDeltaHashCode = _contentController.document.toDelta().hashCode;
    return _initialTitle != title || _initialContentDeltaHashCode != contentDeltaHashCode;
  }

  bool _isSaving = false;
  bool _isLoading = true;

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
    if (localDatabase == null || _noteId == null) return;

    try {
      final noteFromDb = await localDatabase!.query(
        'Notes',
        where: 'id = ?',
        whereArgs: [_noteId],
      );

      if (noteFromDb.isEmpty) {
        _showErrorSnackBar('Catatan tidak ditemukan');
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final note = Note.fromJson(noteFromDb.first);

      if (!mounted) return;

      // Find category
      _category = _categories.firstWhere(
            (cat) => cat.id == note.categoryId,
        orElse: () => _categories.first,
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
    if (localDatabase == null) return;

    try {
      final categoriesFromDb = await localDatabase!.query('Categories');

      if (!mounted) return;

      setState(() {
        _categories = categoriesFromDb
            .map((categoryJson) => Category.fromJson(categoryJson))
            .toList();
      });
    } catch (e) {
      logger.e('Error loading categories: $e');
    }
  }

  Future<void> _showCategoriesDialog() async {
    if (_categories.isEmpty) {
      _showErrorSnackBar('Tidak ada kategori tersedia');
      return;
    }

    Category? selectedCategory = _category;

    final result = await showDialog<Category>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          contentPadding: const EdgeInsets.all(20),
          shape: const BeveledRectangleBorder(),
          title: const Text(
            'Pilih Kategori',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _categories.length,
                itemBuilder: (context, index) => RadioListTile<Category>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_categories[index].name),
                  value: _categories[index],
                  groupValue: selectedCategory,
                  onChanged: (value) => dialogSetState(() => selectedCategory = value),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const BeveledRectangleBorder(),
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(selectedCategory),
              child: const Text('Pilih'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() => _category = result);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showErrorSnackBar('Judul catatan tidak boleh kosong');
      return;
    }

    if (_category == null) {
      await _showCategoriesDialog();
      if (_category == null) return;
    }

    setState(() => _isSaving = true);

    try {
      final delta = _contentController.document.toDelta();
      final now = DateTime.now().toIso8601String();

      final noteData = {
        'title': title,
        'content': DeltaToHTML.encodeJson(delta.toJson()),
        'category_id': _category!.id,
        'updated_at': now,
      };

      final bool isNewNote = _noteId == null;

      if (isNewNote) {
        // Create new note
        noteData['created_at'] = now;
        final savedNoteId = await localDatabase!.insert(
          'Notes',
          noteData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        setState(() => _noteId = savedNoteId);
        logger.d('New note saved with ID: $savedNoteId');
      } else {
        // Update existing note
        await localDatabase!.update(
          'Notes',
          noteData,
          where: 'id = ?',
          whereArgs: [_noteId],
        );
        logger.d('Note updated with ID: $_noteId');
      }

      // Update initial values to reflect saved state
      setState(() {
        _initialTitle = title;
        _initialContentDeltaHashCode = delta.hashCode;
      });

      _showSuccessSnackBar(
        isNewNote ? 'Catatan berhasil disimpan' : 'Catatan berhasil diperbarui',
      );
    } catch (e) {
      logger.e('Error saving note: $e');
      _showErrorSnackBar('Gagal menyimpan catatan: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackPressed,
          ),
          actions: [
            // Category selector button
            TextButton(
              onPressed: _showCategoriesDialog,
              child: Text(
                _category?.name ?? 'Pilih Kategori',
                style: TextStyle(
                  color: _category != null ? Colors.orangeAccent : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Save button
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: Text(
                'Simpan',
                style: TextStyle(
                  color: _isSaving ? Colors.grey : Colors.orangeAccent,
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
            // Title input
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

            // Content editor
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
                      const TextStyle(fontSize: 16, height: 1.4, color: Colors.black),
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

            // Toolbar
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: QuillSimpleToolbar(
                controller: _contentController,
                config: const QuillSimpleToolbarConfig(
                  // Active buttons
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showListNumbers: true,
                  showListBullets: true,
                  showHeaderStyle: true,
                  showUndo: true,
                  showRedo: true,

                  // Disabled buttons
                  showFontFamily: false,
                  showFontSize: false,
                  showStrikeThrough: false,
                  showInlineCode: false,
                  showColorButton: false,
                  showBackgroundColorButton: false,
                  showClearFormat: false,
                  showAlignmentButtons: false,
                  showDirection: false,
                  showListCheck: false,
                  showCodeBlock: false,
                  showQuote: false,
                  showIndent: false,
                  showLink: false,
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