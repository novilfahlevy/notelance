import 'package:logger/logger.dart';
import 'package:notelance/sqflite.dart';
import 'package:sqflite/sqflite.dart';
import 'package:notelance/models/category.dart';

var logger = Logger();

class CategoryLocalRepository {
  Future<List<Category>> get() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> categoriesFromDb = await database.query(
        'Categories',
        where: 'is_deleted != 1',
        orderBy: 'order_index ASC, name ASC',
      );

      return categoriesFromDb
          .map((categoryJson) => Category.fromJson(categoryJson))
          .toList();
    } catch (e) {
      logger.e('Error in CategoryRepository.getCategories method: $e');
      rethrow;
    }
  }

  Future<Category?> getByName(String name) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> categoriesFromDb = await database.query(
          'Categories',
          where: 'LOWER(name) = ? AND is_deleted != 1',
          whereArgs: [name.toLowerCase().trim()]
      );

      if (categoriesFromDb.isEmpty) return null;

      return Category.fromJson(categoriesFromDb.first);
    } catch (e) {
      logger.e('Error in CategoryRepository.getCategoryByName method: $e');
      rethrow;
    }
  }

  Future<Category?> getById(int id) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> categoriesFromDb = await database.query(
          'Categories',
          where: 'id = ? AND is_deleted != 1',
          whereArgs: [id]
      );

      if (categoriesFromDb.isEmpty) return null;

      return Category.fromJson(categoriesFromDb.first);
    } catch (e) {
      logger.e('Error in CategoryRepository.getCategoryByName method: $e');
      rethrow;
    }
  }

  Future<Category?> getByRemoteId(int remoteId) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> categoriesFromDb = await database.query(
          'Categories',
          where: 'remote_id = ? AND is_deleted != 1',
          whereArgs: [remoteId]
      );

      if (categoriesFromDb.isEmpty) return null;

      return Category.fromJson(categoriesFromDb.first);
    } catch (e) {
      logger.e('Error in CategoryRepository.getCategoryByName method: $e');
      rethrow;
    }
  }

  Future<Category> create({
    required String name,
    int? orderIndex,
    int? remoteId
  }) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      // If no order_index specified, get the next available order_index
      // Use the transaction 'txn' if provided, otherwise use the main database instance for _getNextOrder
      int categoryOrder = orderIndex ?? await _getNextOrder();

      final now = DateTime.now().toUtc().toIso8601String();

      final categoryData = {
        'name': name,
        'order_index': categoryOrder,
        'remote_id': remoteId,
        'created_at': now,
        'updated_at': now
      };

      final categoryId = await database.insert('Categories', categoryData);
      categoryData['id'] = categoryId;

      logger.d('Category created with ID: $categoryId, orderIndex: $categoryOrder');
      return Category.fromJson(categoryData);
    } catch (e) {
      logger.e('Error in CategoryRepository.createCategory method: $e');
      rethrow;
    }
  }

  Future<int> _getNextOrder() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final result = await database.rawQuery(
          'SELECT COALESCE(MAX(order_index), -1) + 1 as next_order FROM Categories'
      );
      return result.first['next_order'] as int;
    } catch (e) {
      logger.e('Error in CategoryRepository._getNextOrder method: $e');
      return 0;
    }
  }

  Future<Category> update(
      int id,
      {
        String? name,
        int? orderIndex,
        int? remoteId,
        String? createdAt,
        String? updatedAt
      }
  ) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      Map<String, dynamic> updateData = {};

      if (name != null) {
        updateData['name'] = name;
      }

      if (orderIndex != null) {
        updateData['order_index'] = orderIndex;
      }

      if (remoteId != null) {
        updateData['remote_id'] = remoteId;
      }

      if (createdAt != null) {
        updateData['created_at'] = createdAt;
      }

      if (updatedAt != null) {
        updateData['updated_at'] = updatedAt;
      }

      final updatedRows = await database.update(
        'Categories',
        updateData,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (updatedRows == 0) {
        throw Exception('Category not found');
      }

      logger.d('Category $id updated.');

      final updatedCategory = await getById(id);
      return updatedCategory!;
    } catch (e) {
      logger.e('Error in CategoryRepository.updateCategory method: $e');
      rethrow;
    }
  }

  Future<void> renewOrders(List<Category> categories) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      Batch batch = database.batch();

      for (int i = 0; i < categories.length; i++) {
        final category = categories[i];
        if (category.id != null) {
          batch.update(
            'Categories',
            { 'order_index': i, 'updated_at': DateTime.now().toUtc().toIso8601String() },
            where: 'id = ?',
            whereArgs: [category.id],
          );
        }
      }

      await batch.commit(noResult: true);

      logger.d('Categories order_index updated');
    } catch (e) {
      logger.e('Error in CategoryRepository.renewCategoriesOrder method: $e');
      rethrow;
    }
  }

  Future<void> delete(int categoryId) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // First, detach the category from its notes
      await database.update(
        'Notes',
        { 'category_id': null, 'updated_at': now },
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );

      // Then delete the category
      final deletedRows = await database.update(
        'Categories',
        { 'is_deleted': 1, 'updated_at': now },
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

  Future<void> hardDelete(int id) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      // First, detach the category from its notes
      await database.update(
        'Notes',
        { 'category_id': null, 'updated_at': DateTime.now().toUtc().toIso8601String() },
        where: 'category_id = ?',
        whereArgs: [id],
      );

      // Then delete the category
      final deletedRows = await database.delete(
        'Categories',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (deletedRows == 0) {
        throw Exception('Category not found');
      }

      logger.d('Category $id deleted.');
    } catch (e) {
      logger.e('Error in CategoryRepository.hardDeleteCategory method: $e');
      rethrow;
    }
  }

  Future<List<Category>> getWithTrashed() async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final List<Map<String, dynamic>> categoriesFromDb = await database.query(
        'Categories',
        where: 'is_deleted IN (0, 1)',
      );

      return categoriesFromDb.map((categoryJson) => Category.fromJson(categoryJson)).toList();
    } catch (e) {
      logger.e('Error in CategoryLocalRepository.getWithTrashed method: $e');
      rethrow;
    }
  }

  Future<int> getNotesCount(int categoryId) async {
    final database = LocalDatabaseService.instance.database;
    if (database == null) throw Exception('Database not initialized');

    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM Notes WHERE category_id = ? AND is_deleted != 1',
        [categoryId],
      );

      return result.first['count'] as int;
    } catch (e) {
      logger.e('Error in CategoryRepository.getCategoryNotesCount method: $e');
      rethrow;
    }
  }
}
