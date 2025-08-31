import 'package:flutter/material.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/note_card.dart';
import 'package:notelance/sqflite.dart';
import 'package:notelance/note_editor_page.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, this.category});

  final Category? category;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotes());
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;

    if (!_databaseService.isInitialized) return;

    setState(() => _isLoading = true);

    try {
      late List<Note> notes;

      if (widget.category != null) {
        notes = await _databaseService.getNotesByCategory(widget.category!.id!);
      } else {
        notes = await _databaseService.getUncategorizedNotes();
      }

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
              'Belum ada catatan ${widget.category?.name ?? 'umum'}',
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
          return NoteCard(
            note: _notes[index],
            onEdit: _goToNoteEditor,
            formatDate: _formatDate,
          );
        },
        separatorBuilder: (context, index) {
          return const SizedBox(height: 8);
        },
      ),
    );
  }
}
