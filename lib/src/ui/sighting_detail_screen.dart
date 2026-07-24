/// Detail view for a single stored [Sighting], reached by tapping a Logbook
/// row. Reuses [ResultCard] by rebuilding a display [Candidate] from the
/// sighting, and shows the capture time.
library;

import 'package:flutter/material.dart';

import '../domain/sighting.dart';
import 'format.dart' as fmt;
import 'result_card.dart';

class SightingDetailScreen extends StatelessWidget {
  final Sighting sighting;

  const SightingDetailScreen({super.key, required this.sighting});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(fmt.candidateHeadline(sighting.toCandidate())),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Seen ${fmt.sightingTimestamp(sighting.capturedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ResultCard(
                candidate: sighting.toCandidate(),
                confidence: sighting.confidence,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
