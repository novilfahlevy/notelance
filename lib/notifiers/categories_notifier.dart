import 'package:flutter/material.dart';

class CategoriesNotifier extends ChangeNotifier {
  bool shouldReloadCategories = true;
  
  void reloadCategories() {
    shouldReloadCategories = true;
    notifyListeners();
  }
}