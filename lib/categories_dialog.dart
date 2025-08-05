import 'package:flutter/material.dart';
import 'package:notelance/models/category.dart';

class CategoriesDialog {
  static const Object _newCategorySentinel = Object();

  static Future<CategoriesDialogResult?> show({
    required BuildContext context,
    required List<Category> categories,
    Category? selectedCategory,
  }) async {
    final newCategoryController = TextEditingController();

    final Object? chosenCategory = await showDialog<Object>(
      context: context,
      builder: (context) {
        Object? selectedRadioValue = selectedCategory;
        final newCategoryFocusNode = FocusNode();

        return StatefulBuilder(
          builder: (context, dialogSetState) => AlertDialog(
            contentPadding: const EdgeInsets.all(20),
            shape: const BeveledRectangleBorder(),
            title: const Text(
              'Pilih Kategori',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<Object>(
                      contentPadding: EdgeInsets.zero,
                      title: TextField(
                        controller: newCategoryController,
                        focusNode: newCategoryFocusNode,
                        decoration: const InputDecoration(
                          hintText: 'Buat kategori baru',
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          border: UnderlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          // If user types, ensure "new category" radio is selected
                          if (selectedRadioValue != _newCategorySentinel) {
                            dialogSetState(() {
                              selectedRadioValue = _newCategorySentinel;
                            });
                          }
                        },
                        onTap: () {
                          if (selectedRadioValue != _newCategorySentinel) {
                            dialogSetState(() {
                              selectedRadioValue = _newCategorySentinel;
                            });
                          }
                        },
                      ),
                      value: _newCategorySentinel,
                      groupValue: selectedRadioValue,
                      onChanged: (value) {
                        dialogSetState(() {
                          selectedRadioValue = _newCategorySentinel;
                        });
                        newCategoryFocusNode.requestFocus();
                      },
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return RadioListTile<Object>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(category.name),
                            value: category,
                            groupValue: selectedRadioValue,
                            onChanged: (value) {
                              dialogSetState(() {
                                selectedRadioValue = category;
                                newCategoryController.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  newCategoryFocusNode.dispose();
                  Navigator.of(context).pop();
                },
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const BeveledRectangleBorder(),
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: (selectedCategory == null && newCategoryController.text.trim().isEmpty)
                    ? null
                    : () {
                  newCategoryFocusNode.dispose();
                  if (selectedRadioValue == _newCategorySentinel) {
                    if (newCategoryController.text.trim().isNotEmpty) {
                      Navigator.of(context).pop(_newCategorySentinel);
                    } else {
                      // New category radio selected, but text field is empty
                      Navigator.of(context).pop(); // Effectively a cancel or invalid selection
                    }
                  } else if (selectedRadioValue is Category) {
                    Navigator.of(context).pop(selectedRadioValue as Category);
                  } else {
                    Navigator.of(context).pop(); // Nothing selected
                  }
                },
                child: const Text('Pilih'),
              ),
            ],
          ),
        );
      },
    );

    // Clean up the controller
    final String newCategoryText = newCategoryController.text.trim();
    newCategoryController.dispose();

    // Return the appropriate result
    if (chosenCategory is Category) {
      return CategoriesDialogResult.existingCategory(chosenCategory);
    } else if (chosenCategory == _newCategorySentinel && newCategoryText.isNotEmpty) {
      return CategoriesDialogResult.newCategory(newCategoryText);
    }

    return null; // Dialog was cancelled or no selection
  }
}

/// Result class to handle different types of category selection
class CategoriesDialogResult {
  final Category? existingCategory;
  final String? newCategoryName;
  final bool isNewCategory;

  const CategoriesDialogResult._({
    this.existingCategory,
    this.newCategoryName,
    required this.isNewCategory,
  });

  /// Result for when an existing category is selected
  factory CategoriesDialogResult.existingCategory(Category category) {
    return CategoriesDialogResult._(
      existingCategory: category,
      isNewCategory: false,
    );
  }

  /// Result for when a new category name is provided
  factory CategoriesDialogResult.newCategory(String categoryName) {
    return CategoriesDialogResult._(
      newCategoryName: categoryName,
      isNewCategory: true,
    );
  }
}