import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

Future<bool> hasInternetConnection() async {
  if (Platform.environment.containsKey('VERCEL') || kIsWeb) return true;

  if (Platform.isAndroid || Platform.isIOS || Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.first != ConnectivityResult.none;
    } catch (e) {
      final logger = Logger();
      logger.e('Error checking connectivity: $e');
    }
  }

  return false;
}