import 'package:flutter/material.dart';

class MainPageNotifier extends ChangeNotifier {
  bool shouldReload = true;
  
  void reloadMainPage() {
    shouldReload = true;
    notifyListeners();
  }
}