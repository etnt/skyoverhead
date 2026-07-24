import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/data/preferences_store.dart';
import 'src/data/sighting_store.dart';
import 'src/domain/sighting.dart';
import 'src/state/collector_provider.dart';
import 'src/state/sighting_logger.dart';
import 'src/ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        collectorPreferencesProvider.overrideWithValue(
          SharedPrefsCollectorPreferences(prefs),
        ),
        sightingStoreProvider.overrideWithValue(
          SharedPrefsSightingStore<Sighting>(
            prefs: prefs,
            toJson: (s) => s.toJson(),
            fromJson: Sighting.fromJson,
          ),
        ),
      ],
      child: const SkyOverheadApp(),
    ),
  );
}

class SkyOverheadApp extends StatelessWidget {
  const SkyOverheadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sky Overhead',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
