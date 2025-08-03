import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:delta_to_html/delta_to_html.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/sqllite.dart';
import 'package:sqflite/sqflite.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key});

  static final String path = '/note_editor_page';

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  int? id;

  final TextEditingController _titleController = TextEditingController();
  final QuillController _contentController = QuillController.basic();

  Category? _category;

  List<Category> _categories = [];

  bool _hasUnsavedChanges = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _loadCategories();

    // Listen to document changes
    _contentController.document.changes.listen((event) {
      if (!_hasUnsavedChanges) {
        setState(() => _hasUnsavedChanges = true);
      }
    });

    // Listen to title changes
    _titleController.addListener(() {
      if (!_hasUnsavedChanges) {
        setState(() => _hasUnsavedChanges = true);
      }
    });
  }

  Future<void> _loadCategories() async {
    if (localDatabase == null) return;

    try {
      final List<Map<String, dynamic>> categoriesFromDb = await localDatabase!.query(
        'Categories',
      );
      setState(() {
        _categories = categoriesFromDb
            .map((folderJson) => Category.fromJson(folderJson))
            .toList();
      });
    } catch (e) {
      logger.e(e.toString());
    }
  }

  Future<void> _showCategoriesDialog() {
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
                      itemCount: _categories.length,
                      itemBuilder: (BuildContext context, int index) {
                        return RadioListTile<Category>(
                          contentPadding: EdgeInsets.symmetric(horizontal: 0),
                          title: Text(_categories[index].name),
                          value: _categories[index],
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
      _showCategoriesDialog();
      return;
    }

    setState(() => _isSaving = true);

    try {
      List deltaJson = _contentController.document.toDelta().toJson();

      final noteData = {
        'title': _titleController.text.trim(),
        'content': DeltaToHTML.encodeJson(deltaJson),
        'category_id': _category!.id,
        'updated_at': DateTime.now().toIso8601String()
      };

      int noteId;

      if (id == null) {
        // Create new note
        noteData['created_at'] = DateTime.now().toIso8601String();

        noteId = await localDatabase!.insert(
          'Notes',
          noteData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Set the id when a new note has been saved,
        // so it would not make a new one if the 'Simpan' button is pressed again.
        // Instead, it would update the current saved note
        setState(() => id = noteId);

        logger.d('Catatan baru berhasil disimpan dengan ID: $noteId');
      } else {
        // Update existing note
        noteId = id!;

        await localDatabase!.update(
          'Notes',
          noteData,
          where: 'id = ?',
          whereArgs: [id],
        );

        logger.d('Catatan berhasil diperbarui dengan ID: $noteId');
      }

      noteData['id'] = noteId;

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id == null ? 'Catatan berhasil disimpan' : 'Catatan berhasil diperbarui'),
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
        setState(() {
          _isSaving = false;
          _hasUnsavedChanges = false;
        });
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
    if (!_hasUnsavedChanges) {
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

        if (!_hasUnsavedChanges) return;

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
            // Category selector button
            TextButton(
              onPressed: _showCategoriesDialog,
              child: Text(
                _category != null ? _category!.name : 'Pilih Kategori',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Save button
            TextButton(
              onPressed: _save,
              child: const Text(
                'Simpan',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10,)
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