import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssb_runner/audio/mix_pcm.dart';
import 'package:ssb_runner/contest_run/state_machine/single_call/audio_play_type.dart';
import 'package:ssb_runner/contest_run/state_machine/single_call/single_call_run_state.dart';
import 'package:ssb_runner/contest_type/contest_definition.dart';
import 'package:ssb_runner/db/app_database.dart';
import 'package:ssb_runner/training/session_review.dart';
import 'package:ssb_runner/training/training_profile.dart';

void main() {
  test(
    'contest registry provides the requested common SSB training templates',
    () {
      expect(
        ContestRegistry.all.map((item) => item.id),
        containsAll(<String>[
          'CQ-WPX',
          'CQ-WW-SSB',
          'ARRL-DX',
          'IARU-HF',
          'JIDX-SSB',
        ]),
      );
      expect(ContestRegistry.byId('missing').id, 'CQ-WPX');
    },
  );

  test('pile-up state plays multiple concurrent calls', () {
    final state = WaitingSubmitCall(
      currentCallAnswer: 'BI1ABC',
      currentExchangeAnswer: '12',
      pileupCallsigns: const ['BI1ABC', 'JA1XYZ', 'K1AAA'],
    );
    expect(state.audioPlayType, isA<PlayPileup>());
    expect((state.audioPlayType as PlayPileup).calls, hasLength(3));
  });

  test(
    'audio effects are deterministic and advanced profile speeds audio up',
    () {
      final pcm = Uint8List.fromList(List<int>.generate(80, (index) => index));
      const profile = AudioTrainingProfile(
        playbackRate: 1.18,
        noiseAmount: 0.22,
        fadingAmount: 0.16,
        volume: 1,
        seed: 7,
      );
      final first = AudioTrainingEffects.apply(pcm, profile);
      final second = AudioTrainingEffects.apply(pcm, profile);
      expect(first, second);
      expect(first.length, lessThan(pcm.length));
      expect(mixPcm16([pcm, pcm]).length, greaterThan(pcm.length));
    },
  );

  test(
    'session review records accuracy, error categories, and replay seed',
    () {
      final metadata = TrainingRunMetadata(
        runId: 'run-1',
        contestId: 'CQ-WPX',
        contestName: 'CQ WPX SSB',
        modeId: TrainingMode.pileup.id,
        difficultyId: TrainingDifficulty.advanced.id,
        seed: 99,
        startedAt: DateTime.utc(2026, 1, 1, 12),
      );
      final qsos = <QsoTableData>[
        QsoTableData(
          id: 1,
          utcInSeconds: 20,
          runId: 'run-1',
          stationCallsign: 'BI1ABC',
          callsign: 'JA1XYZ',
          callsignCorrect: 'JA1XYZ',
          exchange: '12',
          exchangeCorrect: '12',
        ),
        QsoTableData(
          id: 2,
          utcInSeconds: 40,
          runId: 'run-1',
          stationCallsign: 'BI1ABC',
          callsign: 'K1ABC',
          callsignCorrect: 'K1ABD',
          exchange: '13',
          exchangeCorrect: '14',
        ),
      ];
      final review = TrainingRunReview.fromQsos(
        metadata: metadata,
        qsos: qsos,
        score: 42,
      );
      expect(review.accuracy, .5);
      expect(review.callsignErrors, 1);
      expect(review.exchangeErrors, 1);
      expect(TrainingRunReview.decode(review.encode()).metadata.seed, 99);
    },
  );
}
