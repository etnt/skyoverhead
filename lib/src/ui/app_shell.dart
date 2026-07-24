/// The app's root shell. When Collector mode is **off** the app is exactly the
/// single [HomeScreen] it has always been. When Collector mode is **on**, a
/// bottom [NavigationBar] appears with a `Sky` tab (the identifier) and a
/// `Logbook` tab (saved sightings). More collector tabs (Medals, Stats) are
/// added in later phases.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/collector_provider.dart';
import 'home_screen.dart';
import 'logbook_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final collectorEnabled = ref.watch(collectorEnabledProvider);

    // Identify-only experience: no navigation chrome at all.
    if (!collectorEnabled) {
      return const HomeScreen();
    }

    // Guard against a stale index if the tab set shrinks.
    final index = _index.clamp(0, 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [HomeScreen(), LogbookScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.travel_explore),
            label: 'Sky',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book),
            label: 'Logbook',
          ),
        ],
      ),
    );
  }
}
