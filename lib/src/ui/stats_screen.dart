/// The Stats tab: a personal-best records board, top-5 lists, a
/// sightings-over-time bar chart and an 8-point compass rose, all derived from
/// the logged sightings. Shows a friendly empty state until data exists.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/records.dart';
import '../domain/statistics.dart';
import '../state/collector_provider.dart';
import '../state/statistics_provider.dart';
import 'format.dart' as fmt;

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider);
    final records = ref.watch(recordsProvider);
    final excluded = ref.watch(excludedAirportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          IconButton(
            tooltip: 'Hidden airports',
            onPressed: () => _openFilters(context),
            icon: excluded.isEmpty
                ? const Icon(Icons.filter_alt_outlined)
                : Badge(
                    label: Text('${excluded.length}'),
                    child: const Icon(Icons.filter_alt),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: stats.total == 0
            ? const _EmptyStats()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _RecordsBoard(records: records),
                  const SizedBox(height: 24),
                  _TopList(
                    title: 'Top destinations',
                    tallies: stats.topDestinations,
                    names: stats.airportNames,
                    onHide: (code) => _confirmHide(context, ref, code),
                  ),
                  const SizedBox(height: 16),
                  _TopList(
                    title: 'Top origins',
                    tallies: stats.topOrigins,
                    names: stats.airportNames,
                    onHide: (code) => _confirmHide(context, ref, code),
                  ),
                  const SizedBox(height: 16),
                  _TopList(title: 'Top airlines', tallies: stats.topAirlines),
                  const SizedBox(height: 16),
                  _TopList(title: 'Top aircraft types', tallies: stats.topTypes),
                  const SizedBox(height: 24),
                  _StatCard(
                    title: 'Activity',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _summaryRow('Total sightings', '${stats.total}'),
                        _summaryRow('Longest day streak',
                            '${stats.longestDayStreak} day'
                            '${stats.longestDayStreak == 1 ? '' : 's'}'),
                        if (stats.rarestDestination != null)
                          _summaryRow('Rarest destination',
                              '${stats.rarestDestination!.key} '
                              '(${stats.rarestDestination!.count})'),
                        if (stats.rarestOrigin != null)
                          _summaryRow('Rarest origin',
                              '${stats.rarestOrigin!.key} '
                              '(${stats.rarestOrigin!.count})'),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 96,
                          child: Semantics(
                            label: 'Sightings per day over the last two weeks',
                            child: _BarChart(perDay: stats.perDay),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _StatCard(
                    title: 'Bearings',
                    child: Center(
                      child: Semantics(
                        label: 'Compass rose showing the directions aircraft '
                            'were seen from',
                        child: SizedBox(
                          width: 180,
                          height: 180,
                          child: CustomPaint(
                            painter: _CompassRosePainter(
                              bins: stats.bearingBins,
                              color: Theme.of(context).colorScheme.primary,
                              gridColor:
                                  Theme.of(context).colorScheme.outlineVariant,
                              labelColor: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Future<void> _confirmHide(
      BuildContext context, WidgetRef ref, String code) async {
    final hide = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hide $code from stats?'),
        content: const Text(
          'This airport is removed from the Top destinations and Top origins '
          'lists. Your logged sightings are not affected — restore it any time '
          'from the filter menu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hide'),
          ),
        ],
      ),
    );
    if ((hide ?? false) && context.mounted) {
      await ref.read(excludedAirportsProvider.notifier).add(code);
    }
  }

  void _openFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _HiddenAirportsSheet(),
    );
  }
}

/// A bottom sheet listing the airports currently hidden from the stats top
/// lists, each restorable with a tap.
class _HiddenAirportsSheet extends ConsumerWidget {
  const _HiddenAirportsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excluded = ref.watch(excludedAirportsProvider);
    final theme = Theme.of(context);
    final codes = excluded.toList()..sort();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hidden airports', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (codes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No hidden airports. Long-press an airport in the Top '
                  'destinations or Top origins list to hide it — handy for a '
                  'home airport that would otherwise dominate.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final code in codes)
                    InputChip(
                      label: Text(code),
                      onDeleted: () =>
                          ref.read(excludedAirportsProvider.notifier).remove(code),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      deleteButtonTooltipMessage: 'Restore $code',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String _recordValue(RecordEntry entry) {
  switch (entry.kind) {
    case RecordKind.highestAltitude:
      return fmt.altitudeText(entry.value, AltitudeSource.none);
    case RecordKind.fastest:
      return fmt.speedText(entry.value) ?? '—';
    case RecordKind.farthest:
    case RecordKind.closest:
      return fmt.distanceText(entry.value);
    case RecordKind.highestOverhead:
      return fmt.elevationText(entry.value);
  }
}

class _RecordsBoard extends StatelessWidget {
  final Map<RecordKind, RecordEntry> records;
  const _RecordsBoard({required this.records});

  @override
  Widget build(BuildContext context) {
    return _StatCard(
      title: 'Records',
      child: Column(
        children: [
          for (final kind in RecordKind.values)
            if (records[kind] case final entry?)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text(kind.label),
                subtitle: Text(
                  fmt.candidateHeadline(entry.sighting.toCandidate()),
                ),
                trailing: Text(
                  _recordValue(entry),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
        ],
      ),
    );
  }
}

class _TopList extends StatelessWidget {
  final String title;
  final List<Tally> tallies;

  /// Optional code → full-name map; when a code resolves, its name is shown as
  /// a secondary line under the code.
  final Map<String, String>? names;

  /// When set, each row can be long-pressed to hide that airport from stats.
  final void Function(String code)? onHide;

  const _TopList({
    required this.title,
    required this.tallies,
    this.names,
    this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StatCard(
      title: title,
      child: tallies.isEmpty
          ? Text(
              'No data yet',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            )
          : Column(
              children: [
                for (final t in tallies)
                  InkWell(
                    onLongPress:
                        onHide == null ? null : () => onHide!(t.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.key),
                                if (names?[t.key] case final name?)
                                  Text(
                                    name,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text('${t.count}'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _StatCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// A simple bar chart of per-day counts across the most recent span of days.
class _BarChart extends StatelessWidget {
  final Map<DateTime, int> perDay;
  const _BarChart({required this.perDay});

  @override
  Widget build(BuildContext context) {
    if (perDay.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final days = perDay.keys.toList()..sort();
    final last = days.last;
    // Render up to the last 14 calendar days ending at the latest sighting.
    const span = 14;
    final counts = <int>[
      for (var i = span - 1; i >= 0; i--)
        perDay[DateTime(last.year, last.month, last.day - i)] ?? 0,
    ];
    final maxCount = counts.fold<int>(1, math.max);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final c in counts)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    height: (constraints.maxHeight * c / maxCount)
                        .clamp(c > 0 ? 3.0 : 0.0, constraints.maxHeight),
                    decoration: BoxDecoration(
                      color: c > 0
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// An 8-point compass rose with petals scaled by per-sector counts.
class _CompassRosePainter extends CustomPainter {
  final List<int> bins;
  final Color color;
  final Color gridColor;
  final Color labelColor;

  _CompassRosePainter({
    required this.bins,
    required this.color,
    required this.gridColor,
    required this.labelColor,
  });

  static const _labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;
    final maxCount = bins.fold<int>(1, math.max);

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, grid);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.65);

    for (var i = 0; i < bins.length; i++) {
      if (bins[i] == 0) continue;
      final length = radius * bins[i] / maxCount;
      // Bin 0 = North (straight up), advancing clockwise.
      final angle = -math.pi / 2 + i * (2 * math.pi / bins.length);
      final tip = center + Offset(math.cos(angle), math.sin(angle)) * length;
      final leftAngle = angle - math.pi / bins.length;
      final rightAngle = angle + math.pi / bins.length;
      final base = length * 0.25;
      final left =
          center + Offset(math.cos(leftAngle), math.sin(leftAngle)) * base;
      final right =
          center + Offset(math.cos(rightAngle), math.sin(rightAngle)) * base;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(path, fill);
    }

    for (var i = 0; i < _labels.length; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / _labels.length);
      final pos =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius + 10);
      final tp = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: TextStyle(color: labelColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CompassRosePainter old) =>
      !_listEquals(old.bins, bins) ||
      old.color != color ||
      old.gridColor != gridColor ||
      old.labelColor != labelColor;

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.query_stats, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('No stats yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Identify a few aircraft and your records and trends will '
              'appear here.',
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
