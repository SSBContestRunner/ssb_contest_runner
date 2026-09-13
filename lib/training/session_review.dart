import 'dart:convert';

import 'package:ssb_runner/db/app_database.dart';

class TrainingRunMetadata {
  const TrainingRunMetadata({
    required this.runId,
    required this.contestId,
    required this.contestName,
    required this.modeId,
    required this.difficultyId,
    required this.seed,
    required this.startedAt,
  });

  final String runId;
  final String contestId;
  final String contestName;
  final String modeId;
  final String difficultyId;
  final int seed;
  final DateTime startedAt;
}

class TrainingRunReview {
  const TrainingRunReview({
    required this.metadata,
    required this.endedAt,
    required this.qsoCount,
    required this.correctCount,
    required this.callsignErrors,
    required this.exchangeErrors,
    required this.score,
  });

  final TrainingRunMetadata metadata;
  final DateTime endedAt;
  final int qsoCount;
  final int correctCount;
  final int callsignErrors;
  final int exchangeErrors;
  final int score;

  double get accuracy => qsoCount == 0 ? 0 : correctCount / qsoCount;
  Duration get duration => endedAt.difference(metadata.startedAt);
  double get qsosPerHour =>
      duration.inSeconds == 0 ? 0 : qsoCount * 3600 / duration.inSeconds;

  factory TrainingRunReview.fromQsos({
    required TrainingRunMetadata metadata,
    required List<QsoTableData> qsos,
    required int score,
  }) {
    final correct = qsos
        .where(
          (qso) =>
              qso.callsign == qso.callsignCorrect &&
              qso.exchange == qso.exchangeCorrect,
        )
        .length;
    return TrainingRunReview(
      metadata: metadata,
      endedAt: DateTime.now().toUtc(),
      qsoCount: qsos.length,
      correctCount: correct,
      callsignErrors: qsos
          .where((qso) => qso.callsign != qso.callsignCorrect)
          .length,
      exchangeErrors: qsos
          .where((qso) => qso.exchange != qso.exchangeCorrect)
          .length,
      score: score,
    );
  }

  Map<String, Object> toJson() => {
    'runId': metadata.runId,
    'contestId': metadata.contestId,
    'contestName': metadata.contestName,
    'modeId': metadata.modeId,
    'difficultyId': metadata.difficultyId,
    'seed': metadata.seed,
    'startedAt': metadata.startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'qsoCount': qsoCount,
    'correctCount': correctCount,
    'callsignErrors': callsignErrors,
    'exchangeErrors': exchangeErrors,
    'score': score,
  };

  String encode() => jsonEncode(toJson());

  factory TrainingRunReview.decode(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return TrainingRunReview(
      metadata: TrainingRunMetadata(
        runId: json['runId'] as String,
        contestId: json['contestId'] as String,
        contestName: json['contestName'] as String,
        modeId: json['modeId'] as String,
        difficultyId: json['difficultyId'] as String,
        seed: json['seed'] as int,
        startedAt: DateTime.parse(json['startedAt'] as String),
      ),
      endedAt: DateTime.parse(json['endedAt'] as String),
      qsoCount: json['qsoCount'] as int,
      correctCount: json['correctCount'] as int,
      callsignErrors: json['callsignErrors'] as int,
      exchangeErrors: json['exchangeErrors'] as int,
      score: json['score'] as int,
    );
  }
}
