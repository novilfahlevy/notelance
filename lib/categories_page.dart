import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:notelance/config.dart';
import 'package:provider/provider.dart';
import 'package:notelance/models/category.dart';
import 'package:notelance/repositories/category_local_repository.dart';
import 'package:notelance/notifiers/categories_notifier.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

var logger = Logger();

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, required this.categories});

  final List<Category> categories;

  static const String path = '/categories_page';

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late List<Category> _categories;
  final CategoryLocalRepository _categoryLocalRepository = CategoryLocalRepository();

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories)..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  /// ----------------------
  /// Internet Connectivity
  /// ----------------------
  Future<bool> _hasInternetConnection() async {
    if (Platform.environment.containsKey('VERCEL') || kIsWeb) return true;

    if (Platform.isAndroid || Platform.isIOS || Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      try {
        final result = await Connectivity().checkConnectivity();
        return result.first != ConnectivityResult.none;
      } catch (e) {
        logger.e('Error checking connectivity: $e');
      }
    }
    return false;
  }

  /// ----------------------
  /// Category Operations
  /// ----------------------

  Future<void> _addCategory(String name) async {
    try {
      final category = await _categoryLocalRepository.create(name: name);

      setState(() => _categories..add(category)..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)));
      if (mounted) context.read<CategoriesNotifier>().reloadCategories();

      _showSnackBar('Berhasil menambah kategori.', Colors.green);
    } catch (e) {
      logger.e('Error adding category: $e');
      if (mounted) _showSnackBar('Telah terjadi kesalahan, gagal membuat kategori.', Theme.of(context).colorScheme.error);
    }
  }

  Future<void> _editCategory(Category category, String newName) async {
    try {
      await _categoryLocalRepository.update(
          category.id!,
          name: newName,
          updatedAt: DateTime.now().toUtc().toIso8601String()
      );

      setState(() {
        final idx = _categories.indexWhere((c) => c.id == category.id);
        if (idx != -1) _categories[idx] = _categories[idx].copyWith(name: newName);
      });

      if (mounted) context.read<CategoriesNotifier>().reloadCategories();
      _showSnackBar('Berhasil mengedit kategori.', Colors.green);
    } catch (e) {
      logger.e('Error updating category: $e');
      if (mounted) _showSnackBar('Telah terjadi kesalahan, gagal mengedit kategori.', Theme.of(context).colorScheme.error);
    }
  }

  Future<void> _deleteCategory(Category category) async {
    try {
      final notesCount = await _categoryLocalRepository.getNotesCount(category.id!);
      if (notesCount > 0) {
        final confirm = await _showDeleteDialog(category.name, notesCount);
        if (!confirm) return;
      }

      await _categoryLocalRepository.delete(category.id!);

      setState(() => _categories.removeWhere((c) => c.id == category.id));
      if (mounted) context.read<CategoriesNotifier>().reloadCategories();

      _showSnackBar('Kategori berhasil dihapus.', Colors.green);
    } catch (e) {
      logger.e('Error deleting category: $e');
      if (mounted) _showSnackBar('Telah terjadi kesalahan, gagal menghapus kategori.', Theme.of(context).colorScheme.error);
    }
  }

  Future<void> _reorderCategories(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);

      for (int i = 0; i < _categories.length; i++) {
        _categories[i] = _categories[i].copyWith(orderIndex: i);
      }
    });

    try {
      await _categoryLocalRepository.renewOrders(_categories);
      if (mounted) context.read<CategoriesNotifier>().reloadCategories();
      logger.i('Categories reordered successfully');
    } catch (e) {
      logger.e('Error reordering categories: $e');
      if (mounted) _showSnackBar('Gagal mengubah urutan kategori: $e', Theme.of(context).colorScheme.error);
    }
  }

  /// ----------------------
  /// UI Helpers
  /// ----------------------

  void _showSnackBar(String message, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _showDeleteDialog(String name, int notesCount) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kategori', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Kategori "$name" memiliki $notesCount catatan. '
            'Menghapus kategori akan membuat catatan tersebut menjadi catatan umum. Apakah Anda yakin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _showCategoryDialog({Category? category}) {
    final controller = TextEditingController(text: category?.name ?? '');
    final isEdit = category != null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Kategori' : 'Tambah Kategori',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty || (isEdit && name == category.name)) return;

              try {
                final existing = await _categoryLocalRepository.getByName(name);
                if (existing != null && existing.id != category?.id && mounted) {
                  _showSnackBar('Kategori "$name" sudah ada', Theme.of(context).colorScheme.surfaceVariant);
                  return;
                }

                if (mounted) Navigator.pop(context);
                isEdit ? _editCategory(category, name) : _addCategory(name);
              } catch (e) {
                logger.e('Error checking category name: $e');
                final exists = _categories.any((c) => c.id != category?.id && c.name.toLowerCase() == name.toLowerCase());
                if (exists) {
                  if (mounted) _showSnackBar('Kategori "$name" sudah ada', Theme.of(context).colorScheme.surfaceVariant);
                  return;
                }
                if (mounted) Navigator.pop(context);
                isEdit ? _editCategory(category, name) : _addCategory(name);
              }
            },
            child: Text(isEdit ? 'Simpan' : 'Tambah'),
          ),
        ],
      ),
    );
  }

  /// ----------------------
  /// Build UI
  /// ----------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtleTextColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.7);
    final subtleIconColor = theme.iconTheme.color?.withOpacity(0.7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showCategoryDialog())],
      ),
      body: _categories.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: subtleIconColor ?? theme.disabledColor),
            const SizedBox(height: 16),
            Text('Belum ada kategori',
                style: TextStyle(fontSize: 18, color: subtleTextColor ?? theme.disabledColor)),
            const SizedBox(height: 8),
            Text('Tap tombol + untuk menambah kategori',
                style: TextStyle(color: subtleTextColor ?? theme.disabledColor)),
          ],
        ),
      )
          : ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: 100),
        onReorder: _reorderCategories,
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final category = _categories[i];
          return Card(
            key: ValueKey(category.id),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              leading: ReorderableDragStartListener(
                index: i,
                child: Icon(Icons.drag_handle, color: theme.iconTheme.color?.withOpacity(0.6)),
              ),
              title: Text(category.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _showCategoryDialog(category: category),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () => _deleteCategory(category),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
