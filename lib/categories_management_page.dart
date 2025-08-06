import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/sqllite.dart';
import 'package:notelance/notifiers/categories_notifier.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class CategoriesManagementPage extends StatefulWidget {
  const CategoriesManagementPage({super.key, required this.categories});

  final List<Category> categories;

  static final String path = '/categories_management_page';

  @override
  State<CategoriesManagementPage> createState() => _CategoriesManagementPageState();
}

class _CategoriesManagementPageState extends State<CategoriesManagementPage> {
  late List<Category> _categories;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
  }

  Future<void> _addCategory(String categoryName) async {
    if (localDatabase == null) return;

    try {
      // Insert into database
      final categoryId = await localDatabase!.insert(
        'Categories',
        {
          'name': categoryName,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
      );

      // Create new category object
      final newCategory = Category(
        id: categoryId,
        name: categoryName
      );

      // Update local list
      setState(() {
        _categories.add(newCategory);
      });

      // Notify other parts of the app to reload categories
      if (mounted) {
        context.read<CategoriesNotifier>().reloadCategories();
      }

      logger.i('Category added: $categoryName');
    } catch (e) {
      logger.e('Error adding category: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambah kategori: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCategory(Category category) async {
    if (localDatabase == null) return;

    try {
      // Check if category has notes
      final notesCount = await localDatabase!.rawQuery(
        'SELECT COUNT(*) as count FROM Notes WHERE category_id = ?',
        [category.id],
      );

      final count = notesCount.first['count'] as int;

      if (count > 0) {
        // Show warning dialog if category has notes
        final shouldDelete = await _showDeleteWarningDialog(category.name, count);
        if (!shouldDelete) return;

        // Delete all notes in this category first
        await localDatabase!.delete(
          'Notes',
          where: 'category_id = ?',
          whereArgs: [category.id],
        );
      }

      // Delete category from database
      await localDatabase!.delete(
        'Categories',
        where: 'id = ?',
        whereArgs: [category.id],
      );

      // Update local list
      setState(() {
        _categories.removeWhere((cat) => cat.id == category.id);
      });

      // Notify other parts of the app to reload categories
      if (mounted) {
        context.read<CategoriesNotifier>().reloadCategories();
      }

      logger.i('Category deleted: ${category.name}');
    } catch (e) {
      logger.e('Error deleting category: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus kategori: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteWarningDialog(String categoryName, int notesCount) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Hapus Kategori', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
          content: Text(
            'Kategori "$categoryName" memiliki $notesCount catatan. '
                'Menghapus kategori akan menghapus semua catatan di dalamnya. '
                'Apakah Anda yakin?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Hapus'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showAddCategoryDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Tambah Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                final categoryName = controller.text.trim();
                if (categoryName.isNotEmpty) {
                  // Check if category name already exists
                  final exists = _categories.any((cat) =>
                  cat.name.toLowerCase() == categoryName.toLowerCase());

                  if (exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kategori dengan nama "$categoryName" sudah ada'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  Navigator.of(context).pop();
                  _addCategory(categoryName);
                }
              },
              child: Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  void _showEditCategoryDialog(Category category) {
    final TextEditingController controller = TextEditingController(text: category.name);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Kategori', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                final newCategoryName = controller.text.trim();
                if (newCategoryName.isNotEmpty && newCategoryName != category.name) {
                  // Check if category name already exists
                  final exists = _categories.any((cat) =>
                  cat.id != category.id &&
                      cat.name.toLowerCase() == newCategoryName.toLowerCase());

                  if (exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kategori dengan nama "$newCategoryName" sudah ada'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  Navigator.of(context).pop();
                  _editCategory(category, newCategoryName);
                }
              },
              child: Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editCategory(Category category, String newName) async {
    if (localDatabase == null) return;

    try {
      // Update in database
      await localDatabase!.update(
        'Categories',
        {'name': newName},
        where: 'id = ?',
        whereArgs: [category.id],
      );

      // Update local list
      setState(() {
        final index = _categories.indexWhere((cat) => cat.id == category.id);
        if (index != -1) {
          _categories[index] = Category(
            id: category.id,
            name: newName
          );
        }
      });

      // Notify other parts of the app to reload categories
      if (mounted) {
        context.read<CategoriesNotifier>().reloadCategories();
      }

      logger.i('Category updated: ${category.name} -> $newName');
    } catch (e) {
      logger.e('Error updating category: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah kategori: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Kategori'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddCategoryDialog,
          ),
        ],
      ),
      body: _categories.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Belum ada kategori',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tap tombol + untuk menambah kategori',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.separated(
        itemBuilder: (context, index) {
          final category = _categories[index];
          final ListTile categoryTile = ListTile(
            contentPadding: EdgeInsets.only(left: 20, right: 10),
            title: Text(category.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, size: 18),
                  onPressed: () => _showEditCategoryDialog(category),
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () => _deleteCategory(category),
                )
              ],
            ),
          );

          if (index < _categories.length - 1) {
            return categoryTile;
          }

          return Column(children: [categoryTile, SizedBox(height: 150)]);
        },
        separatorBuilder: (context, index) => Divider(),
        itemCount: _categories.length,
      ),
    );
  }
}