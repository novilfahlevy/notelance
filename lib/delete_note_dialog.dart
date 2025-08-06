import 'package:flutter/material.dart';

class DeleteNoteDialog {
  static Future<bool> show({
    required BuildContext context,
    String? noteTitle,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const BeveledRectangleBorder(),
        title: const Text(
          'Hapus Catatan?',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Catatan yang dihapus tidak dapat dikembalikan. Apakah Anda yakin ingin menghapus catatan ini?',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Hapus',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}