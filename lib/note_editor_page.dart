import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:delta_to_html/delta_to_html.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/sqllite.dart';
import 'package:sqflite/sqflite.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key});

  static final String path = '/note_editor_page';

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final QuillController _contentController = QuillController.basic();

  Category? _category;

  bool _hasUnsavedChanges = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Listen to document changes
    _contentController.document.changes.listen((event) {
      if (!_hasUnsavedChanges) {
        setState(() => _hasUnsavedChanges = true);
      }
    });
  }

  Future<void> _showCategoriesDialog() {
    // TODO: Load the categories from database
    final List<Category> categories = [
      Category(id: 1, name: 'Kategori 1'),
      Category(id: 2, name: 'Kategori 2'),
      Category(id: 3, name: 'Kategori 3'),
      Category(id: 4, name: 'Kategori 4'),
      Category(id: 5, name: 'Kategori 5'),
      Category(id: 6, name: 'Kategori 6'),
      Category(id: 7, name: 'Kategori 7'),
      Category(id: 8, name: 'Kategori 8'),
    ];

    Category? selectedCategory = _category;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, StateSetter dialogSetState) {
            return AlertDialog(
              contentPadding: EdgeInsets.all(20),
              shape: BeveledRectangleBorder(),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 300,
                ),
                child: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    shrinkWrap: true,
                    itemCount: categories.length,
                    itemBuilder: (BuildContext context, int index) {
                      return RadioListTile<Category>(
                        contentPadding: EdgeInsets.symmetric(horizontal: 0),
                        title: Text(categories[index].name),
                        value: categories[index],
                        groupValue: selectedCategory,
                        onChanged: (Category? value) {
                          dialogSetState(() => selectedCategory = value);
                        },
                      );
                    },
                  ),
                ),
              ),
              actions: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: BeveledRectangleBorder(),
                      backgroundColor: Colors.orangeAccent
                    ),
                    onPressed: () {
                      if (selectedCategory != null) {
                        setState(() => _category = selectedCategory);
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text('Pilih', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _save() async {
    if (_category == null) {
      // TODO: Ask to choose the category first before saves the note
      return;
    }

    setState(() => _isSaving = true);

    try {
      List deltaJson = _contentController.document.toDelta().toJson();

      final newNoteData = {
        'title': _titleController.text.trim(),
        'content': DeltaToHTML.encodeJson(deltaJson),
        'category_id': _category!.id,
        'created_at': DateTime.now(),
        'updated_at': DateTime.now()
      };

      final int id = await localDatabase!.insert(
        'Notes',
        newNoteData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      newNoteData['id'] = id;

      final newNote = Note.fromJson(newNoteData);

      // Log the saving
      logger.d('Catatan berhasil disimpan: ${newNote.toString()}');

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Catatan berhasil disimpan'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      // Log the error
      logger.e('Error saat menyimpan catatan: ${e.toString()}');

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan catatan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<bool> _showExitConfirmation() async {
    if (!_hasUnsavedChanges && _titleController.text.isEmpty) {
      return true;
    }

    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Batalkan penulisan?'),
          content: const Text('Catatan akan terbuang jika belum disimpan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Keluar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Tetap menulis'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        final bool shouldPop = await _showExitConfirmation();

        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final bool shouldPop = await _showExitConfirmation();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                // TODO: Implements saving logic here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.orangeAccent,
                    content: Text('Catatan berhasil disimpan'),
                    duration: Duration(seconds: 2),
                  ),
                );

                setState(() => _hasUnsavedChanges = false);
              },
              child: const Text(
                'Simpan',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                  hintText: 'Nama catatan',
                  hintStyle: TextStyle(fontSize: 18, color: Colors.grey),
                  border: UnderlineInputBorder(borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.all(10)
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: QuillEditor(
                controller: _contentController,
                scrollController: ScrollController(),
                config: QuillEditorConfig(
                  placeholder: 'Tulis disini...',
                  padding: EdgeInsets.all(10),
                  expands: true,
                  customStyles: DefaultStyles(
                    paragraph: DefaultTextBlockStyle(
                      TextStyle(fontSize: 14, color: Colors.black),
                      HorizontalSpacing.zero,
                      VerticalSpacing.zero,
                      VerticalSpacing.zero,
                      null,
                    ),
                    placeHolder: DefaultTextBlockStyle(
                      TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      HorizontalSpacing.zero,
                      VerticalSpacing.zero,
                      VerticalSpacing.zero,
                      null,
                    ),
                  ),
                ),
                focusNode: FocusNode(),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _showCategoriesDialog,
                  style: ElevatedButton.styleFrom(
                    shape: LinearBorder(),
                    elevation: 0.0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(_category != null ? _category!.name : 'Pilih kategori')
              ),
            ),
            QuillSimpleToolbar(
              controller: _contentController,
              config: const QuillSimpleToolbarConfig(
                // Aktif
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showListNumbers: true,
                showListBullets: true,
                showHeaderStyle: true,

                // Nonaktif
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
                showUndo: false,
                showRedo: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                showSmallButton: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
