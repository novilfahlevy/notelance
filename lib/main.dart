// Flutter framework
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Third-party packages
import 'package:flutter_quill/flutter_quill.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Local project imports
import 'package:notelance/config.dart';
import 'package:notelance/pages/main_page.dart';
import 'package:notelance/view_models/main_page_view_model.dart';
import 'package:notelance/pages/search_page.dart';
import 'package:notelance/local_database.dart';

var logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Config.load();

  await LocalDatabase.instance.initialize();

  await Supabase.initialize(
    url: Config.instance.supabaseUrl,
    anonKey: Config.instance.supabaseAnonKey,
  );

  if (Config.instance.isSentryEnabled) {
    await SentryFlutter.init(
      (options) {
        options.dsn = Config.instance.sentryDsn;
        options.sendDefaultPii = true;
      },
      appRunner: () => runApp(
        SentryWidget(child: const Notelance()),
      ),
    );
  } else {
    runApp(const Notelance());
  }
}

class Notelance extends StatelessWidget {
  const Notelance({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MainPageViewModel(),
      child: MaterialApp(
          title: 'Notelance',
          debugShowCheckedModeBanner: false,

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),

          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF202124), // Main background
            scaffoldBackgroundColor: const Color(0xFF202124), // Scaffold background
            cardColor: const Color(0xFF303134), // Card/surface color
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Colors.amber, // Accent for FAB
              foregroundColor: Colors.black, // Icon/text on FAB
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF202124), // AppBar background
              elevation: 0, // No shadow for a flatter look
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            tabBarTheme: const TabBarThemeData(
              labelColor: Colors.amber, // Selected tab text color
              unselectedLabelColor: Colors.grey, // Unselected tab text color
              indicatorColor: Colors.amber, // Tab indicator color
            ),
            iconTheme: const IconThemeData(color: Colors.white), // Default icon color
            textTheme: const TextTheme( // Default text styles
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
              titleLarge: TextStyle(color: Colors.white),
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.amber,
              brightness: Brightness.dark,
              background: const Color(0xFF202124), // Overall background
              surface: const Color(0xFF303134), // Surfaces like cards
              primary: Colors.amber, // Primary actions/highlights
            ),
            useMaterial3: true,
          ),

          themeMode: ThemeMode.dark, // Set dark theme as default

          routes: {
            MainPage.path: (_) => ChangeNotifierProvider<MainPageViewModel>(
              create: (_) => MainPageViewModel(),
              child: MainPage(),
            ),
            SearchPage.path: (_) => SearchPage()
          },

          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ]
      ),
    );
  }
}