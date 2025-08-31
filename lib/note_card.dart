import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:notelance/models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final Function(Note) onEdit;
  final String Function(DateTime) formatDate;

  const NoteCard({
    super.key,
    required this.note,
    required this.onEdit,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: Colors.orangeAccent,
      shape: const BeveledRectangleBorder(),
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
                    color: Colors.white),
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
            const SizedBox(
              height: 15,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDate(DateTime.parse(note.updatedAt!)),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                InkWell(
                  onTap: () => onEdit(note),
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
  }
}
