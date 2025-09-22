import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:notelance/repositories/note_local_repository.dart'; // Added
import 'package:notelance/models/note.dart';
import 'package:notelance/note_editor_page.dart';
import 'package:flutter_html/flutter_html.dart';

var logger = Logger();

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  static final String path = '/search_page';

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _keywordController = TextEditingController();
  final NoteLocalRepository _noteRepository = NoteLocalRepository();

  List<Note> _notes = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounceTimer;

  static const Duration _debounceDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _keywordController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();

    if (_keywordController.text.trim().isEmpty) {
      setState(() {
        _notes.clear();
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    if (!_isSearching) {
      setState(() {
        _isSearching = true;
      });
    }

    _debounceTimer = Timer(_debounceDuration, () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _keywordController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _notes.clear();
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }

    try {
      final searchedNotes = await _noteRepository.search(query);

      if (mounted) {
        setState(() {
          _notes = searchedNotes;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      logger.e('Error in _performSearch: $e');
      if (mounted) {
        setState(() {
          _notes.clear();
          _isSearching = false;
          _hasSearched = true;
        });

        final theme = Theme.of(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching notes: ${e.toString()}'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _goToNoteEditor(Note note) {
    Navigator.pushNamed(
      context,
      NoteEditorPage.path,
      arguments: note,
    ).then((_) {
      if (_keywordController.text.trim().isNotEmpty) {
        _performSearch();
      }
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

  Widget _buildSearchResults() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Mencari catatan...',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: theme.iconTheme.color?.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'Ketik kata kunci untuk mencari catatan',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: theme.iconTheme.color?.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'Tidak ada catatan yang ditemukan',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 200),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return Card(
          elevation: 1,
          shadowColor: theme.shadowColor.withOpacity(0.2),
          color: colorScheme.surface, // ✅ use surface for background
          shape: const BeveledRectangleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.title.isNotEmpty) ...[
                  Text(
                    note.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface, // ✅ text adapts to surface
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                ],
                SelectableRegion(
                  focusNode: FocusNode(),
                  selectionControls: MaterialTextSelectionControls(),
                  child: Html(
                    data: note.content!,
                    style: {
                      "body": Style(
                        color: colorScheme.onSurface,
                        margin: Margins.all(0),
                        padding: HtmlPaddings.all(0),
                      ),
                      'p': Style(
                        color: colorScheme.onSurface,
                        margin: Margins.all(0),
                        padding: HtmlPaddings.all(0),
                      ),
                      '*': Style(
                        margin: Margins.all(0),
                        padding: HtmlPaddings.all(0),
                      ),
                    },
                  ),
                ),
                Divider(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  height: 0,
                  thickness: 0.5,
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(DateTime.parse(note.updatedAt!)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    InkWell(
                      onTap: () => _goToNoteEditor(note),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.edit_note,
                          color: colorScheme.primary,
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 8),
    );
  }

  Widget _buildSearchResultsCount() {
    final theme = Theme.of(context);

    if (!_hasSearched || _isSearching || _notes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        'Ditemukan ${_notes.length} catatan',
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _keywordController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Cari catatan...',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
            ),
            border: InputBorder.none,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
          textInputAction: TextInputAction.search,
        ),
        actions: [
          if (_keywordController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _keywordController.clear();
                FocusScope.of(context).requestFocus(FocusNode());
              },
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchResultsCount(),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }
}
