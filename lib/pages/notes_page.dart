// Flutter framework
import 'package:flutter/material.dart';

// Third-party packages
import 'package:logger/logger.dart';

// Local project imports
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/pages/components/note_card.dart';
import 'package:notelance/pages/note_editor_page.dart';

var logger = Logger();

class NotesPage extends StatefulWidget {
  const NotesPage({
    super.key,
    required this.category,
    required this.notes,
    required this.loadNotes
  });

  final Category? category;
  final List<Note> notes;
  final Future<void> Function() loadNotes;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _goToNoteEditor(Note note) {
    Navigator.pushNamed(
      context,
      NoteEditorPage.path,
      arguments: note,
    ).then((_) => widget.loadNotes());
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now().toUtc();
    final difference = now.difference(dateTime.toUtc());

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Baru saja';
        }
        return '${difference.inMinutes} menit yang lalu';
      } else if (difference.inHours < 7) {
        return '${difference.inHours} jam yang lalu';
      } else {
        return 'Kemarin';
      }
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.notes.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.loadNotes,
        color: colorScheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum ada catatan ${widget.category?.name ?? 'umum'}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tekan tombol + untuk membuat catatan baru',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.loadNotes,
      color: colorScheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: widget.notes.length,
        itemBuilder: (context, index) {
          if (index >= widget.notes.length - 1) {
            return Column(
              children: [
                NoteCard(
                  note: widget.notes[index],
                  onEdit: _goToNoteEditor,
                  formatDate: _formatDate,
                ),
                SizedBox(height: 200,)
              ],
            );
          }

          return NoteCard(
            note: widget.notes[index],
            onEdit: _goToNoteEditor,
            formatDate: _formatDate,
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 8),
      ),
    );
  }
}
