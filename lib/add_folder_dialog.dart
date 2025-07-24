import 'package:flutter/material.dart';
import 'package:notelance/models/folder.dart';
import 'package:notelance/sqllite.dart';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

var logger = Logger();

class AddFolderDialog extends StatefulWidget {
  const AddFolderDialog({ super.key, required this.onAdded });

  final Function(Folder folder) onAdded;

  @override
  State<AddFolderDialog> createState() => _AddFolderDialogState();
}

class _AddFolderDialogState extends State<AddFolderDialog> {
  final TextEditingController _folderNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addFolder(String folderName) async {
    if (database == null || folderName.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final int id = await database!.insert(
        'Folders',
        { 'name': folderName.trim() },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final newFolder = Folder(id: id, name: folderName.trim());
      widget.onAdded(newFolder);

      logger.d('Folder added successfully: ${newFolder.toString()}');
    } catch (e) {
      logger.e('Error adding folder: ${e.toString()}');

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan folder: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _folderNameController,
            decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelText: 'Nama folder',
              hintText: 'Masukkan nama folder',
              enabled: !_isLoading,
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (value) async {
              if (value.trim().isNotEmpty && !_isLoading) {
                await _addFolder(value);
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: Text('Batal'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    if (_folderNameController.text.trim().isNotEmpty) {
                      await _addFolder(_folderNameController.text);
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  child: _isLoading
                      ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text('Buat'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}