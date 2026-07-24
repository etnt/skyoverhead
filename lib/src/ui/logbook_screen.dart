/// The Logbook tab: a reverse-chronological list of saved [Sighting]s, with an
/// empty state when nothing has been collected yet. Tapping a row opens the
/// [SightingDetailScreen].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sighting.dart';
import '../state/sighting_logger.dart';
import 'format.dart' as fmt;
import 'sighting_detail_screen.dart';

class LogbookScreen extends ConsumerWidget {
  const LogbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sightings = ref.watch(sightingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Logbook')),
      body: SafeArea(
        child: sightings.isEmpty
            ? const _EmptyLogbook()
            : ListView.separated(
                itemCount: sightings.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _SightingRow(sighting: sightings[index]),
              ),
      ),
    );
  }
}

class _SightingRow extends StatelessWidget {
  final Sighting sighting;
  const _SightingRow({required this.sighting});

  @override
  Widget build(BuildContext context) {
    final candidate = sighting.toCandidate();
    final headline = fmt.candidateHeadline(candidate);
    final route = fmt.routeText(candidate);
    final subtitleParts = <String>[
      ?route,
      fmt.sightingTimestamp(sighting.capturedAt),
    ];

    return ListTile(
      leading: _Thumbnail(url: sighting.photoUrl),
      title: Text(headline),
      subtitle: Text(subtitleParts.join('  ·  ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SightingDetailScreen(sighting: sighting),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? url;
  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = CircleAvatar(
      backgroundColor: scheme.surfaceContainerHighest,
      child: Icon(Icons.flight, color: scheme.onSurfaceVariant, size: 20),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _EmptyLogbook extends StatelessWidget {
  const _EmptyLogbook();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('No sightings yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Point at the sky and identify an aircraft — it will show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
