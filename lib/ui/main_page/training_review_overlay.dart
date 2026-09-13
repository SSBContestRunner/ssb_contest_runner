import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ssb_runner/contest_run/new/contest_manager.dart';
import 'package:ssb_runner/training/session_review.dart';

class TrainingReviewOverlay extends StatefulWidget {
  const TrainingReviewOverlay({super.key});
  @override
  State<TrainingReviewOverlay> createState() => _TrainingReviewOverlayState();
}

class _TrainingReviewOverlayState extends State<TrainingReviewOverlay> {
  StreamSubscription<TrainingRunReview>? _subscription;
  TrainingRunReview? _review;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscription ??= context.read<ContestManager>().reviewStream.listen(
      (review) => mounted ? setState(() => _review = review) : null,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    if (review == null) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Training review',
      liveRegion: true,
      child: ColoredBox(
        color: color.scrim.withAlpha(150),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 510),
            child: Material(
              color: color.surface,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session review',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${review.metadata.contestName} · ${review.metadata.modeId} · ${review.metadata.difficultyId}',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        _stat('QSOs', '${review.qsoCount}'),
                        _stat(
                          'Accuracy',
                          '${(review.accuracy * 100).toStringAsFixed(1)}%',
                        ),
                        _stat(
                          'Rate',
                          '${review.qsosPerHour.toStringAsFixed(1)}/h',
                        ),
                        _stat('Score', '${review.score}'),
                        _stat('Call errors', '${review.callsignErrors}'),
                        _stat('Exchange errors', '${review.exchangeErrors}'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Replay seed: ${review.metadata.seed}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => setState(() => _review = null),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => SizedBox(
    width: 125,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
