import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:delta_to_html/delta_to_html.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key});

  static final String path = '/note_editor_page';

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final QuillController _contentController = QuillController.basic();

  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();

    // Listen to document changes
    _contentController.document.changes.listen((event) {
      // TODO: Use this to compare the current content to the old content
      List deltaJson = _contentController.document.toDelta().toJson();

      if (!_hasUnsavedChanges) {
        setState(() => _hasUnsavedChanges = true);
      }
    });
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
