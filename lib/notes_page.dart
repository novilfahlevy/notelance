import 'package:flutter/material.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/sqllite.dart';
import 'package:notelance/note_editor_page.dart';

class NotesPage extends StatefulWidget {
  final Category category;

  const NotesPage({super.key, required this.category});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with AutomaticKeepAliveClientMixin {
  List<Note> _notes = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (localDatabase == null) return;

    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> notesFromDb = await localDatabase!.query(
        'Notes',
        where: 'category_id = ?',
        whereArgs: [widget.category.id],
        orderBy: 'updated_at DESC', // Show most recently updated notes first
      );

      setState(() {
        _notes = notesFromDb
            .map((noteJson) => Note.fromJson(noteJson))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Error loading notes: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNote(Note note) async {
    try {
      await localDatabase!.delete(
        'Notes',
        where: 'id = ?',
        whereArgs: [note.id],
      );

      // Remove the note from the list
      setState(() {
        _notes.removeWhere((n) => n.id == note.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Catatan "${note.title}" berhasil dihapus'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Batalkan',
              textColor: Colors.white,
              onPressed: () {
                // TODO: Implement undo functionality if needed
              },
            ),
          ),
        );
      }

      logger.d('Note deleted: ${note.title}');
    } catch (e) {
      logger.e('Error deleting note: ${e.toString()}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus catatan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(Note note) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Catatan'),
          content: Text('Apakah Anda yakin ingin menghapus catatan "${note.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteNote(note);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  void _editNote(Note note) {
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
    int lastSpace = preview.lastIndexOf(' ', cutOff);

    // If we found a space and it's not too close to the beginning
    if (lastSpace > 50) {
      return '${preview.substring(0, lastSpace)}...';
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
              onTap: () => _editNote(note),
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