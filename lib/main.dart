import 'package:auto_upgrade/auto_upgrade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/config/app_version.dart';
import 'src/data/preferences_store.dart';
import 'src/data/saved_location_store.dart';
import 'src/data/sighting_store.dart';
import 'src/data/update_service.dart';
import 'src/domain/sighting.dart';
import 'src/state/collector_provider.dart';
import 'src/state/saved_locations_provider.dart';
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
        savedLocationStoreProvider.overrideWithValue(
          SharedPrefsSavedLocationStore(prefs: prefs),
        ),
        releaseCheckerProvider.overrideWithValue(
          ReleaseChecker(
            owner: 'etnt',
            repo: 'skyoverhead',
            currentVersion: appVersion,
            // Throttles the GitHub check to at most once per interval
            // across restarts. Errors and 'dev' builds stay silent.
            checkStore: SharedPrefsUpdateCheckStore(prefs),
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
