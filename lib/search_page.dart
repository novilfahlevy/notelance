import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:notelance/sqflite.dart';
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
  final LocalDatabaseService _databaseService = LocalDatabaseService.instance;

  List<Note> _notes = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounceTimer;

  // Debounce duration
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
    // Cancel the previous timer
    _debounceTimer?.cancel();

    // If search field is empty, clear results immediately
    if (_keywordController.text.trim().isEmpty) {
      setState(() {
        _notes.clear();
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    // Set searching state immediately for better UX
    if (!_isSearching) {
      setState(() {
        _isSearching = true;
      });
    }

    // Start a new timer
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
      final searchedNotes = await _databaseService.searchNotes(query);

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

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching notes: ${e.toString()}'),
            backgroundColor: Colors.red,
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
      // Refresh search results when returning from editor
      if (_keywordController.text.trim().isNotEmpty) {
        _performSearch();
      }
    });
  }

  String _getPreviewText(String content) {
    // Remove HTML tags for preview
    String preview = content.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove excessive whitespace
    preview = preview.replaceAll(RegExp(r'[ \t]+'), ' ').trim();

    if (preview.isEmpty) return 'Catatan kosong';

    // Limit to 100 characters while preserving words
    if (preview.length <= 100) {
      return preview;
    }

    int cutOff = 100;
    int lastSpaceIndex = preview.lastIndexOf(' ', cutOff);

    if (lastSpaceIndex > 50) {
      return '${preview.substring(0, lastSpaceIndex)}...';
    } else {
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

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.orangeAccent,
            ),
            SizedBox(height: 16),
            Text(
              'Mencari catatan...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
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
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Ketik kata kunci untuk mencari catatan',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            )
          ],
        ),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada catatan yang ditemukan',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            )
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return Card(
          elevation: 0,
          shadowColor: Colors.transparent,
          color: Colors.orangeAccent,
          shape: BeveledRectangleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.title.isNotEmpty) ...[
                  Text(
                    note.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                        color: Colors.white
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
                        color: Colors.white,
                        margin: Margins.all(0),
                        padding: HtmlPaddings.all(0),
                      ),
                      'p': Style(
                        color: Colors.white,
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
                const Divider(color: Colors.white54, height: 0, thickness: 0.5),
                const SizedBox(height: 15,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(DateTime.parse(note.updatedAt!)),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    InkWell(
                      onTap: () => _goToNoteEditor(note),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4), // Small touch target
                        child: Icon(Icons.edit_note, color: Colors.white),
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
    if (!_hasSearched || _isSearching || _notes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        'Ditemukan ${_notes.length} catatan',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _keywordController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Cari catatan...',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 16),
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
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }
}