import 'dart:async';

import 'package:drift/drift.dart';
import 'package:ssb_runner/audio/audio_player.dart';
import 'package:ssb_runner/contest_run/new/contest_data_manager.dart';
import 'package:ssb_runner/contest_run/new/contest_input_handler.dart';
import 'package:ssb_runner/contest_run/new/contest_running_manager.dart';
import 'package:ssb_runner/contest_run/new/contest_timer.dart';
import 'package:ssb_runner/contest_type/contest_type.dart';
import 'package:ssb_runner/contest_type/contest_definition.dart';
import 'package:ssb_runner/db/app_database.dart';
import 'package:ssb_runner/training/session_review.dart';
import 'package:ssb_runner/training/training_profile.dart';
import 'package:uuid/uuid.dart';

class ContestManager {
  final ContestDataManager _contestDataManager;

  ContestManager({required ContestDataManager contestDataManager})
    : _contestDataManager = contestDataManager;

  late final ContestTimer contestTimer = ContestTimer(
    onContestEnd: () {
      stopContest();
    },
  );

  String _currentContestRunId = '';
  final _contestRunIdStreamController = StreamController<String>.broadcast();

  Stream<String> get contestRunIdStream => _contestRunIdStreamController.stream;

  late final AppDatabase _appDatabase = _contestDataManager.appDatabase;

  ContestRunningManager? contestRunningManager;

  bool _isContestRunning = false;
  final _isContestRunningStreamController = StreamController<bool>.broadcast();

  Stream<bool> get isContestRunningStream =>
      _isContestRunningStreamController.stream;

  bool get isContestRunning => _isContestRunning;

  late final AudioPlayer _audioPlayer = _contestDataManager.audioPlayer;
  late final ContestInputHandler _contestInputHandler =
      _contestDataManager.inputHandler;

  final _contestTypeStreamController =
      StreamController<ContestType>.broadcast();

  Stream<ContestType> get contestTypeStream =>
      _contestTypeStreamController.stream;

  final _reviewStreamController =
      StreamController<TrainingRunReview>.broadcast();
  Stream<TrainingRunReview> get reviewStream => _reviewStreamController.stream;

  TrainingRunMetadata? _activeRun;
  ContestType? _activeContestType;

  void startContest() {
    final runId = Uuid().v4();
    _currentContestRunId = runId;
    _contestRunIdStreamController.sink.add(runId);

    _audioPlayer.startPlay();
    _contestInputHandler.clear();

    final dxccManager = _contestDataManager.dxccManager;
    final settings = _contestDataManager.appSettings;
    final definition = ContestRegistry.byId(settings.contestId);
    final mode = TrainingMode.fromId(settings.contestModeId);
    final difficulty = settings.difficulty;
    final seed =
        settings.replaySeed ??
        (DateTime.now().microsecondsSinceEpoch & 0x7fffffff);
    final contestType = definition.create(
      stationCallsign: settings.stationCallsign,
      dxccManager: dxccManager,
    );
    _activeRun = TrainingRunMetadata(
      runId: runId,
      contestId: definition.id,
      contestName: definition.name,
      modeId: mode.id,
      difficultyId: difficulty.id,
      seed: seed,
      startedAt: DateTime.now().toUtc(),
    );
    _activeContestType = contestType;

    _audioPlayer.setTrainingProfile(
      AudioTrainingProfile.fromDifficulty(
        difficulty: difficulty,
        volume: settings.audioVolume,
        seed: seed,
      ),
    );

    _contestTypeStreamController.sink.add(contestType);
    contestRunningManager = _createContestRunningManager(
      runId,
      contestType,
      mode: mode,
      difficulty: difficulty,
      seed: seed,
    );

    final durationInMinutes = _contestDataManager.appSettings.contestDuration;
    contestTimer.start(durationInMinutes);

    _isContestRunning = true;
    _isContestRunningStreamController.sink.add(true);
  }

  ContestRunningManager _createContestRunningManager(
    String runId,
    ContestType contestType, {
    required TrainingMode mode,
    required TrainingDifficulty difficulty,
    required int seed,
  }) {
    return ContestRunningManager(
      runId: runId,
      contestTimer: contestTimer,
      contestType: contestType,
      contestDataManager: _contestDataManager,
      scoreCalculator: contestType.scoreCalculator,
      mode: mode,
      difficulty: difficulty,
      seed: seed,
    );
  }

  void stopContest() {
    if (!_isContestRunning) return;
    final run = _activeRun;
    final contestType = _activeContestType;
    contestTimer.stop();
    contestRunningManager?.stop();

    _audioPlayer.stopPlay();

    _isContestRunning = false;
    _isContestRunningStreamController.sink.add(false);
    if (run != null && contestType != null) {
      _saveReview(run, contestType);
    }
  }

  Future<void> _saveReview(
    TrainingRunMetadata run,
    ContestType contestType,
  ) async {
    final qsos =
        await (_appDatabase.qsoTable.select()
              ..where((row) => row.runId.equals(run.runId)))
            .get();
    final review = TrainingRunReview.fromQsos(
      metadata: run,
      qsos: qsos,
      score: contestType.scoreCalculator.calculateScore(qsos).score,
    );
    _contestDataManager.appSettings.saveSessionReview(review);
    _reviewStreamController.add(review);
  }

  Future<int> countCurrentRunQso() async {
    return await _appDatabase.qsoTable
            .count(
              where: (row) {
                return row.runId.equals(_currentContestRunId);
              },
            )
            .getSingleOrNull() ??
        0;
  }

  Future<List<int>> recentCurrentRunQsoTimes({int limit = 6}) async {
    final qsos =
        await (_appDatabase.qsoTable.select()
              ..where((row) => row.runId.equals(_currentContestRunId))
              ..orderBy([(row) => OrderingTerm.asc(row.utcInSeconds)]))
            .get();
    return qsos
        .map((qso) => qso.utcInSeconds)
        .toList()
        .reversed
        .take(limit)
        .toList()
        .reversed
        .toList();
  }
}
