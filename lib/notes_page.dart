import 'package:flutter/material.dart';
import 'package:notelance/models/category.dart';

class NotesPage extends StatelessWidget {
  final Category category;
  
  const NotesPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: 3, // This should be dynamic based on actual notes
      itemBuilder: (context, index) {
        return ListTile(
          tileColor: Colors.amber,
          contentPadding: const EdgeInsets.all(16),
          title: Text(
            'Note ${index + 1} in ${category.name}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              // Handle menu actions here
            },
          ),
        );
      },
      separatorBuilder: (context, index) {
        return const SizedBox(height: 10);
      },
    );
  }
}