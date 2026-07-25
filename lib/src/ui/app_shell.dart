/// The app's root shell. When Collector mode is **off** the app is exactly the
/// single [HomeScreen] it has always been. When Collector mode is **on**, a
/// bottom [NavigationBar] appears with a `Sky` tab (the identifier), a
/// `Logbook` tab (saved sightings), a `Medals` tab (collections &
/// achievements) and a `Stats` tab (records & trends).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/collector_provider.dart';
import 'home_screen.dart';
import 'logbook_screen.dart';
import 'medals_screen.dart';
import 'stats_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final collectorEnabled = ref.watch(collectorEnabledProvider);

    // Identify-only experience: no navigation chrome at all.
    if (!collectorEnabled) {
      return const HomeScreen();
    }

    // Guard against a stale index if the tab set shrinks.
    final index = ref.watch(selectedTabProvider).clamp(0, 3);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          HomeScreen(),
          LogbookScreen(),
          MedalsScreen(),
          StatsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(selectedTabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.travel_explore),
            label: 'Sky',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book),
            label: 'Logbook',
          ),
          NavigationDestination(
            icon: Icon(Icons.military_tech),
            label: 'Medals',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}
