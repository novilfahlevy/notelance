import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/sqflite.dart';
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
  final LocalDatabaseService _databaseService = LocalDatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
    _categories.sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> _addCategory(String categoryName) async {
    try {
      // Create new category using the service
      final newCategory = await _databaseService.createCategory(categoryName);

      // Update local list
      setState(() {
        _categories.add(newCategory);
        // Re-sort to maintain order
        _categories.sort((a, b) => a.order.compareTo(b.order));
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
    try {
      // Check if category has notes
      final notesCount = await _databaseService.getCategoryNotesCount(category.id!);

      if (notesCount > 0) {
        // Show warning dialog if category has notes
        final shouldDelete = await _showDeleteWarningDialog(category.name, notesCount);
        if (!shouldDelete) return;
      }

      // Delete category using the service
      await _databaseService.deleteCategory(category.id!);

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

  Future<void> _reorderCategories(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final Category item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);

      // Update order values
      for (int i = 0; i < _categories.length; i++) {
        _categories[i] = _categories[i].copyWith(order: i);
      }
    });

    try {
      // Update order in database
      await _databaseService.updateCategoriesOrder(_categories);

      // Notify other parts of the app to reload categories
      if (mounted) {
        context.read<CategoriesNotifier>().reloadCategories();
      }

      logger.i('Categories reordered successfully');
    } catch (e) {
      logger.e('Error reordering categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah urutan kategori: ${e.toString()}'),
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
    try {
      // Update using the service
      await _databaseService.updateCategory(category.id!, newName);

      // Update local list
      setState(() {
        final index = _categories.indexWhere((cat) => cat.id == category.id);
        if (index != -1) {
          _categories[index] = _categories[index].copyWith(name: newName);
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
          : Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: EdgeInsets.only(bottom: 100),
              onReorder: _reorderCategories,
              itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return Card(
                    key: ValueKey(category.id),
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.only(left: 10, right: 10),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Icon(Icons.drag_handle, color: Colors.grey.shade600),
                      ),
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
                          ),
                        ],
                      ),
                    ),
                  );
                }
            ),
          ),
        ],
      ),
    );
  }
}