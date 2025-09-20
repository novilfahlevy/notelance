import 'package:flutter/material.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/models/note.dart';
import 'package:notelance/note_card.dart';
import 'package:notelance/repositories/note_local_repository.dart'; // Added
import 'package:notelance/note_editor_page.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, this.category});

  final Category? category;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage>
    with AutomaticKeepAliveClientMixin {
  List<Note> _notes = [];
  bool _isLoading = true;
  final NoteLocalRepository _noteRepository = NoteLocalRepository(); // Changed

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotes());
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;

    // Changed: Removed _databaseService.isInitialized check

    setState(() => _isLoading = true);

    try {
      late List<Note> notes;

      if (widget.category != null) {
        // Changed: Used _noteRepository
        notes = await _noteRepository.getNotesByCategory(widget.category!.id!);
      } else {
        // Changed: Used _noteRepository
        notes = await _noteRepository.getUncategorizedNotes();
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
    Navigator.pushNamed(
      context,
      NoteEditorPage.path,
      arguments: note,
    ).then((_) {
      _loadNotes();
    });
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

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: colorScheme.primary,
        ),
      );
    }

    if (_notes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNotes,
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
      onRefresh: _loadNotes,
      color: colorScheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        physics: const AlwaysScrollableScrollPhysics(), // 👈 ensures pull even if few items
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          if (index >= _notes.length - 1) {
            return Column(
              children: [
                NoteCard(
                  note: _notes[index],
                  onEdit: _goToNoteEditor,
                  formatDate: _formatDate,
                ),
                SizedBox(height: 300,)
              ],
            );
          }

          return NoteCard(
            note: _notes[index],
            onEdit: _goToNoteEditor,
            formatDate: _formatDate,
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 8),
      ),
    );
  }
}
