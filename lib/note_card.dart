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
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color onSurfaceColor = theme.colorScheme.onSurface;
    final Color onSurfaceColorMuted = theme.colorScheme.onSurface.withOpacity(0.7);

    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: theme.cardColor, // Use theme card color
      shape: const BeveledRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.title.isNotEmpty) ...[
              Text(
                note.title,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                    color: onSurfaceColor
                ),
              ),
              const SizedBox(height: 20),
            ],
            SelectableRegion(
              focusNode: FocusNode(),
              selectionControls: MaterialTextSelectionControls(),
              child: Html(
                data: note.content!,
                style: {
                  "body": Style(
                    color: onSurfaceColor, // Use theme text color
                    margin: Margins.all(0),
                    padding: HtmlPaddings.all(0),
                  ),
                  'p': Style(
                    color: onSurfaceColor, // Use theme text color
                    margin: Margins.all(0),
                    padding: HtmlPaddings.all(0),
                  ),
                  '*': Style(
                    color: onSurfaceColor, // Use theme text color
                    margin: Margins.all(0),
                    padding: HtmlPaddings.all(0),
                  ),
                },
              ),
            ),
            Divider(color: theme.dividerColor.withOpacity(0.5), height: 0, thickness: 0.5), // Use theme divider color
            const SizedBox(
              height: 15,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDate(DateTime.parse(note.updatedAt!)),
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurfaceColorMuted, // Use theme muted text color
                  ),
                ),
                InkWell(
                  onTap: () => onEdit(note),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.edit_note, color: primaryColor,),
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
