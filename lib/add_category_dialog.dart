import 'package:flutter/material.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/sqllite.dart';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

var logger = Logger();

class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({ super.key, required this.onAdded });

  final Function(Category category) onAdded;

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final TextEditingController _folderNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addCategory(String folderName) async {
    if (localDatabase == null || folderName.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final int id = await localDatabase!.insert(
        'Categories',
        { 'name': folderName.trim() },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final newCategory = Category(id: id, name: folderName.trim());
      widget.onAdded(newCategory);

      logger.d('Category added successfully: ${newCategory.toString()}');
    } catch (e) {
      logger.e('Error adding category: ${e.toString()}');

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan category: ${e.toString()}'),
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
              labelText: 'Nama kategori',
              enabled: !_isLoading,
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (value) async {
              if (value.trim().isNotEmpty && !_isLoading) {
                await _addCategory(value);
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
                      await _addCategory(_folderNameController.text);
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