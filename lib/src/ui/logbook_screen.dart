/// The Logbook tab: a reverse-chronological list of saved [Sighting]s, with an
/// empty state when nothing has been collected yet. The list renders in pages
/// of [kLogbookPageSize] with a "Show more" footer so a large history stays
/// cheap to render (the underlying data is always complete). Tapping a row
/// opens the [SightingDetailScreen].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sighting.dart';
import '../state/sighting_logger.dart';
import 'format.dart' as fmt;
import 'sighting_detail_screen.dart';

/// How many logbook rows are revealed per page.
const int kLogbookPageSize = 50;

class LogbookScreen extends ConsumerStatefulWidget {
  const LogbookScreen({super.key});

  @override
  ConsumerState<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends ConsumerState<LogbookScreen> {
  int _visible = kLogbookPageSize;

  @override
  Widget build(BuildContext context) {
    final sightings = ref.watch(sightingsProvider);
    final shown = sightings.length < _visible ? sightings.length : _visible;
    final hasMore = sightings.length > shown;

    return Scaffold(
      appBar: AppBar(title: const Text('Logbook')),
      body: SafeArea(
        child: sightings.isEmpty
            ? const _EmptyLogbook()
            : ListView.separated(
                itemCount: shown + (hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index >= shown) {
                    return _ShowMoreTile(
                      remaining: sightings.length - shown,
                      onPressed: () => setState(
                        () => _visible += kLogbookPageSize,
                      ),
                    );
                  }
                  final sighting = sightings[index];
                  return Dismissible(
                    key: ObjectKey(sighting),
                    direction: DismissDirection.endToStart,
                    background: const _DeleteBackground(),
                    confirmDismiss: (_) => _confirmDelete(context, sighting),
                    onDismissed: (_) => _deleteSighting(context, sighting),
                    child: _SightingRow(sighting: sighting),
                  );
                },
              ),
      ),
    );
  }

  /// Ask the user to confirm removing [sighting] from the logbook.
  Future<bool> _confirmDelete(BuildContext context, Sighting sighting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sighting?'),
        content: const Text(
          'This removes the observation and its stored data. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _deleteSighting(BuildContext context, Sighting sighting) {
    ref.read(sightingStoreProvider).remove(sighting);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Sighting deleted')));
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.errorContainer,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

class _ShowMoreTile extends StatelessWidget {
  final int remaining;
  final VoidCallback onPressed;
  const _ShowMoreTile({required this.remaining, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.expand_more),
          label: Text('Show more ($remaining)'),
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
        semanticLabel: 'Aircraft photo',
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
