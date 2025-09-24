import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static Config? _instance;
  static bool _isEnvLoaded = false;

  static Config get instance => _instance ??= Config._internal();

  Config._internal() {
    _ensureEnvLoaded();
  }

  // Static method to load environment variables
  static Future<void> load({ String fileName = '.env' }) async {
    await dotenv.load(fileName: fileName);
    _isEnvLoaded = true;
  }

  // Private method to ensure dotenv is loaded
  void _ensureEnvLoaded() {
    if (!_isEnvLoaded) {
      // Check if dotenv has any values loaded
      if (dotenv.env.isEmpty) {
        throw StateError(
            'Environment variables not loaded. Please call Config.load() first, '
                'or ensure dotenv.load() has been called before accessing Config.instance.'
        );
      }
      _isEnvLoaded = true;
    }
  }

  // Supabase Configuration
  String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  String get supabaseFunctionName => dotenv.env['SUPABASE_FUNCTION_NAME'] ?? '';
  String get supabaseFunctionUrl => dotenv.env['SUPABASE_FUNCTION_URL'] ?? '';
  String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  String get supabaseServiceRoleKey => dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

  // Sentry Configuration
  String get sentryDsn => dotenv.env['SENTRY_DSN'] ?? '';
  bool get isSentryEnabled => _parseBool(dotenv.env['SENTRY_ENABLED']);

  // Helper method to parse boolean values from environment variables
  bool _parseBool(String? value) {
    if (value == null) return false;
    return value.toLowerCase() == 'true';
  }

  // Method to check if all required environment variables are loaded
  bool get isAllConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseFunctionName.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        supabaseServiceRoleKey.isNotEmpty &&
        sentryDsn.isNotEmpty;
  }

  // Method to get environment summary (useful for debugging)
  Map<String, dynamic> getConfigSummary() {
    return {
      'supabaseUrl': supabaseUrl.isNotEmpty ? 'Set' : 'Missing',
      'supabaseFunctionName': supabaseFunctionName.isNotEmpty ? 'Set' : 'Missing',
      'supabaseFunctionUrl': supabaseFunctionUrl.isNotEmpty ? 'Set' : 'Missing',
      'supabaseAnonKey': supabaseAnonKey.isNotEmpty ? 'Set' : 'Missing',
      'supabaseServiceRoleKey': supabaseServiceRoleKey.isNotEmpty ? 'Set' : 'Missing',
      'sentryDsn': sentryDsn.isNotEmpty ? 'Set' : 'Missing',
      'isSentryEnabled': isSentryEnabled,
      'isAllConfigured': isAllConfigured,
    };
  }
}