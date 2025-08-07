import 'package:flutter/material.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/local_database_service.dart';
import 'package:notelance/note_editor_page.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.category});

  final Category category;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with AutomaticKeepAliveClientMixin {
  List<Note> _notes = [];
  bool _isLoading = true;
  final LocalDatabaseService _databaseService = LocalDatabaseService.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (!_databaseService.isInitialized) return;

    setState(() => _isLoading = true);

    try {
      final notes = await _databaseService.getNotesByCategory(widget.category.id!);
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Error loading notes: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  void _goToNoteEditor(Note note) {
    // Navigate to note editor with the selected note data
    Navigator.pushNamed(
      context,
      NoteEditorPage.path,
      arguments: note,
    ).then((_) {
      // Refresh the notes list when returning from editor
      _loadNotes();
    });
  }

  String _getPreviewText(String content) {
    // Remove HTML tags for preview (simple approach)
    String preview = content.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove excessive whitespace but keep newlines
    preview = preview.replaceAll(RegExp(r'[ \t]+'), ' ').trim();

    if (preview.isEmpty) return 'Catatan kosong';

    // Limit to 100 characters while preserving words
    if (preview.length <= 100) {
      return preview;
    }

    // Find the last space before the 100 character limit
    int cutOff = 100;
    int lastSpaceIndex = preview.lastIndexOf(' ', cutOff);

    // If we found a space and it's not too close to the beginning
    if (lastSpaceIndex > 50) {
      return '${preview.substring(0, lastSpaceIndex)}...';
    } else {
      // If no suitable space found, cut at 100 characters
      return '${preview.substring(0, 100)}...';
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Baru saja';
        }
        return '${difference.inMinutes} menit yang lalu';
      }
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.orangeAccent,
        ),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Belum ada catatan di ${widget.category.name}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tekan tombol + untuk membuat catatan baru',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      color: Colors.orangeAccent,
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];

          return Card(
            elevation: 0,
            shadowColor: Colors.transparent,
            color: Colors.orangeAccent,
            shape: BeveledRectangleBorder(),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              title: Text(
                note.title.isEmpty ? 'Catatan tanpa judul' : note.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    _getPreviewText(note.content!),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(DateTime.parse(note.updatedAt!)),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              onTap: () => _goToNoteEditor(note),
            ),
          );
        },
        separatorBuilder: (context, index) {
          return const SizedBox(height: 8);
        },
      ),
    );
  }
}