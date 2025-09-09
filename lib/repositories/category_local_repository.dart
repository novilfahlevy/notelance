import 'package:logger/logger.dart';
import 'package:notelance/sqflite.dart';
import 'package:sqflite/sqflite.dart';
import 'package:notelance/models/category.dart';

var logger = Logger();

class CategoryLocalRepository {
  Future<List<Category>> getCategories() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> categoriesFromDb = await database.query(
        'Categories',
        orderBy: 'order_index ASC, name ASC',
      );

      return categoriesFromDb
          .map((categoryJson) => Category.fromJson({
        'id': categoryJson['id'],
        'name': categoryJson['name'],
        'order': categoryJson['order_index'] ?? 0,
      }))
          .toList();
    } catch (e) {
      logger.e('Error in CategoryRepository.getCategories method: $e');
      rethrow;
    }
  }

  Future<Category?> getCategoryByName(String name) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> categoriesFromDb = await database.query(
          'Categories',
          where: 'LOWER(name) = ?',
          whereArgs: [name.toLowerCase().trim()]
      );

      if (categoriesFromDb.isEmpty) return null;

      return Category.fromJson(categoriesFromDb.first);
    } catch (e) {
      logger.e('Error in CategoryRepository.getCategoryByName method: $e');
      rethrow;
    }
  }

  Future<Category> createCategory({ required String name, int? order }) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      // If no order specified, get the next available order
      // Use the transaction 'txn' if provided, otherwise use the main database instance for _getNextCategoryOrder
      int categoryOrder = order ?? await _getNextCategoryOrder();

      final categoryId = await database.insert(
        'Categories',
        {
          'name': name,
          'order_index': categoryOrder,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
      );

      logger.d('Category created with ID: $categoryId, order: $categoryOrder');

      return Category(id: categoryId, name: name, order: categoryOrder);
    } catch (e) {
      logger.e('Error in CategoryRepository.createCategory method: $e');
      rethrow;
    }
  }

  Future<int> _getNextCategoryOrder() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final result = await database.rawQuery(
          'SELECT COALESCE(MAX(order_index), -1) + 1 as next_order FROM Categories'
      );
      return result.first['next_order'] as int;
    } catch (e) {
      logger.e('Error in CategoryRepository._getNextCategoryOrder method: $e');
      return 0;
    }
  }

  Future<void> updateCategory(int categoryId, { String? name, int? order, int? remoteId }) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      Map<String, dynamic> updateData = {};

      if (name != null) {
        updateData['name'] = name;
      }

      if (order != null) {
        updateData['order_index'] = order;
      }

      if (remoteId != null) {
        updateData['remote_id'] = remoteId;
      }

      final updatedRows = await database.update(
        'Categories',
        updateData,
        where: 'id = ?',
        whereArgs: [categoryId],
      );

      if (updatedRows == 0) {
        throw Exception('Category not found');
      }

      logger.d('Category $categoryId updated.');
    } catch (e) {
      logger.e('Error in CategoryRepository.updateCategory method: $e');
      rethrow;
    }
  }

  Future<void> renewCategoriesOrder(List<Category> categories) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      Batch batch = database.batch();

      for (int i = 0; i < categories.length; i++) {
        final category = categories[i];
        if (category.id != null) {
          batch.update(
            'Categories',
            {'order_index': i},
            where: 'id = ?',
            whereArgs: [category.id],
          );
        }
      }

      await batch.commit(noResult: true);

      logger.d('Categories order updated');
    } catch (e) {
      logger.e('Error in CategoryRepository.renewCategoriesOrder method: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(int categoryId) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      // First delete all notes in this category
      await database.delete(
        'Notes',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );

      // Then delete the category
      final deletedRows = await database.delete(
        'Categories',
        where: 'id = ?',
        whereArgs: [categoryId],
      );

      if (deletedRows == 0) {
        throw Exception('Category not found');
      }

      logger.d('Category $categoryId deleted.');
    } catch (e) {
      logger.e('Error in CategoryRepository.deleteCategory method: $e');
      rethrow;
    }
  }

  Future<int> getCategoryNotesCount(int categoryId) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM Notes WHERE category_id = ?',
        [categoryId],
      );

      return result.first['count'] as int;
    } catch (e) {
      logger.e('Error in CategoryRepository.getCategoryNotesCount method: $e');
      rethrow;
    }
  }
}
