import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/repositories/category_local_repository.dart';
import 'package:notelance/notifiers/categories_notifier.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, required this.categories});

  final List<Category> categories;

  static final String path = '/categories_page';

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late List<Category> _categories;
  final CategoryLocalRepository _categoryRepository = CategoryLocalRepository();

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
    _categories.sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> _addCategory(String categoryName) async {
    try {
      // Create new category using the repository
      final newCategory = await _categoryRepository.createCategory(name: categoryName);

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
      final notesCount = await _categoryRepository.getCategoryNotesCount(category.id!);

      if (notesCount > 0) {
        // Show warning dialog if category has notes
        final shouldDelete = await _showDeleteWarningDialog(category.name, notesCount);
        if (!shouldDelete) return;
      }

      // Delete category using the repository
      await _categoryRepository.deleteCategory(category.id!);

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
      // Update order in database using repository
      await _categoryRepository.renewCategoriesOrder(_categories);

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
              onPressed: () async {
                final categoryName = controller.text.trim();
                if (categoryName.isNotEmpty) {
                  try {
                    // Check if category name already exists using repository
                    final existingCategory = await _categoryRepository.getCategoryByName(categoryName);

                    if (existingCategory != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Kategori dengan nama "$categoryName" sudah ada'),
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    if (context.mounted) Navigator.of(context).pop();
                    _addCategory(categoryName);
                  } catch (e) {
                    logger.e('Error checking category name: $e');
                    // Fall back to local check if database check fails
                    final exists = _categories.any((cat) =>
                    cat.name.toLowerCase() == categoryName.toLowerCase());

                    if (exists && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Kategori dengan nama "$categoryName" sudah ada'),
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    if (context.mounted) Navigator.of(context).pop();
                    _addCategory(categoryName);
                  }
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
              onPressed: () async {
                final newCategoryName = controller.text.trim();
                if (newCategoryName.isNotEmpty && newCategoryName != category.name) {
                  try {
                    // Check if category name already exists using repository
                    final existingCategory = await _categoryRepository.getCategoryByName(newCategoryName);

                    if (existingCategory != null && existingCategory.id != category.id && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Kategori dengan nama "$newCategoryName" sudah ada'),
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    if (context.mounted) Navigator.of(context).pop();
                    _editCategory(category, newCategoryName);
                  } catch (e) {
                    logger.e('Error checking category name: $e');
                    // Fall back to local check if database check fails
                    final exists = _categories.any((cat) =>
                    cat.id != category.id &&
                        cat.name.toLowerCase() == newCategoryName.toLowerCase());

                    if (exists && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Kategori dengan nama "$newCategoryName" sudah ada'),
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    if (context.mounted) Navigator.of(context).pop();
                    _editCategory(category, newCategoryName);
                  }
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
      // Update using the repository
      await _categoryRepository.updateCategory(category.id!, name: newName);

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
    final ThemeData theme = Theme.of(context);
    final Color? subtleTextColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.7);
    final Color? subtleIconColor = theme.iconTheme.color?.withOpacity(0.7);

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
            Icon(Icons.folder_open, size: 64, color: subtleIconColor ?? theme.disabledColor),
            SizedBox(height: 16),
            Text(
              'Belum ada kategori',
              style: TextStyle(fontSize: 18, color: subtleTextColor ?? theme.disabledColor),
            ),
            SizedBox(height: 8),
            Text(
              'Tap tombol + untuk menambah kategori',
              style: TextStyle(color: subtleTextColor ?? theme.disabledColor),
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
                        child: Icon(Icons.drag_handle, color: theme.iconTheme.color?.withOpacity(0.6) ?? theme.disabledColor),
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