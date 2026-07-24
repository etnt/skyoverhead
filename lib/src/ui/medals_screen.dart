/// The Medals tab: a shelf of earned/locked medals with progress bars, plus a
/// compact summary of the unique-key collection counts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collections.dart';
import '../domain/medals.dart';
import '../state/medals_provider.dart';

class MedalsScreen extends ConsumerWidget {
  const MedalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medals = ref.watch(medalsProvider);
    final counts = ref.watch(collectionCountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Medals')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CollectionsCard(counts: counts),
            const SizedBox(height: 24),
            Text('Shelf', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
              children: [
                for (final medal in medals) _MedalTile(medal: medal),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionsCard extends StatelessWidget {
  final Map<CollectionKind, int> counts;
  const _CollectionsCard({required this.counts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Collections', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in CollectionKind.values)
                  Chip(
                    avatar: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${counts[kind] ?? 0}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    label: Text(kind.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MedalTile extends StatelessWidget {
  final Medal medal;
  const _MedalTile({required this.medal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final earned = medal.earned;
    final accent = earned ? scheme.primary : scheme.onSurfaceVariant;

    return Card(
      color: earned ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              earned ? Icons.military_tech : Icons.lock_outline,
              color: accent,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              medal.title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: earned ? scheme.onPrimaryContainer : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                medal.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: earned
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: medal.ratio,
                minHeight: 6,
                backgroundColor: scheme.surface,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              earned ? 'Earned' : '${medal.progress} / ${medal.target}',
              style: theme.textTheme.labelSmall?.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}
