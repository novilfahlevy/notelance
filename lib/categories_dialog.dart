import 'package:flutter/material.dart';
import 'package:notelance/models/category.dart';

class CategoriesDialog {
  static const Object _newCategorySentinel = Object();

  static Future<CategoriesDialogResult?> show({
    required BuildContext context,
    required List<Category> categories,
    Category? selectedCategory,
    String? newCategoryNameInputError, // Added new parameter
  }) async {
    final newCategoryController = TextEditingController();

    // If there was a previous input error, keep the text field focused.
    bool shouldFocusNewCategory = newCategoryNameInputError != null;

    final Object? chosenCategory = await showDialog<Object>(
      context: context,
      builder: (context) {
        Object? selectedRadioValue = selectedCategory;
        // If there's an error, assume user was trying to create a new category.
        if (newCategoryNameInputError != null) {
          selectedRadioValue = _newCategorySentinel;
        }
        final newCategoryFocusNode = FocusNode();

        // Request focus after the dialog is built if there was an error
        if (shouldFocusNewCategory) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            newCategoryFocusNode.requestFocus();
          });
        }

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
                      title: Column( // Wrap TextField in a Column to show error below
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: newCategoryController,
                            focusNode: newCategoryFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Buat kategori baru',
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              border: const UnderlineInputBorder(),
                              isDense: true,
                              errorText: newCategoryNameInputError, // Display error text
                              errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                            onChanged: (value) {
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
                        ],
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
                                // Clear error when another option is selected
                                // newCategoryNameInputError = null; // This won't work directly here
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
                onPressed: selectedRadioValue == null
                    ? null
                    : () {
                  // Do not pop if there's an error and new category is selected
                  if (selectedRadioValue == _newCategorySentinel &&
                      newCategoryNameInputError != null &&
                      newCategoryController.text.trim().isNotEmpty // Or based on your validation logic
                      ) {
                        // Potentially trigger validation again or just keep dialog open
                        // For now, let the existing logic in note_editor_page handle re-showing the dialog
                        // This button press will try to pop with _newCategorySentinel
                        // and note_editor_page will re-validate.
                  }

                  newCategoryFocusNode.dispose();
                  if (selectedRadioValue == _newCategorySentinel) {
                    // We pop with _newCategorySentinel, note_editor_page will validate
                    // newCategoryController.text.
                    // If it was empty and an error was shown, it still pops with _newCategorySentinel,
                    // which is then ignored by note_editor_page if text is empty.
                     Navigator.of(context).pop(_newCategorySentinel);
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
      // The validation for non-empty is already here,
      // the duplicate check happens in note_editor_page before calling show again.
      return CategoriesDialogResult.newCategory(newCategoryText);
    }

    return null; // Dialog was cancelled or no selection (or empty new category name)
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