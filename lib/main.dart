import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_shell.dart';
import 'core/settings/settings_controller.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled in assets/fonts — a missing font must fail loudly in
  // debug (and fall back silently in release), never reach the network.
  GoogleFonts.config.allowRuntimeFetching = false;
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const BibleConnectApp(),
  ));
}

class BibleConnectApp extends StatelessWidget {
  const BibleConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set again here (idempotent) so widget tests that pump this app without
    // running main() also load fonts strictly offline.
    GoogleFonts.config.allowRuntimeFetching = false;
    return MaterialApp(
      title: 'Bible Connect',
      debugShowCheckedModeBanner: false,
      theme: lightTheme(ColorScheme.fromSeed(seedColor: AppColors.accent)),
      darkTheme: darkTheme(ColorScheme.fromSeed(
        seedColor: AppColors.nightAccent,
        brightness: Brightness.dark,
      )),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
