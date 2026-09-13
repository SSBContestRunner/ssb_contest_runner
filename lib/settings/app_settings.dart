import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssb_runner/audio/audio_loader.dart';
import 'package:ssb_runner/common/constants.dart';
import 'package:ssb_runner/contest_type/contest_definition.dart';
import 'package:ssb_runner/training/training_profile.dart';
import 'package:ssb_runner/training/session_review.dart';

class AppSettings {
  final SharedPreferencesWithCache _prefs;

  AppSettings({required SharedPreferencesWithCache prefs}) : _prefs = prefs;

  String get contestId =>
      _prefs.getString(_settingContestId) ?? ContestRegistry.all.first.id;

  set contestId(String value) => _prefs.setString(_settingContestId, value);

  String get contestModeId =>
      _prefs.getString(_settingContestMode) ?? TrainingMode.run.id;

  set contestModeId(String value) =>
      _prefs.setString(_settingContestMode, value);

  String get stationCallsign => _prefs.getString(_settingStationCallsign) ?? '';

  set stationCallsign(String value) =>
      _prefs.setString(_settingStationCallsign, value);

  int get contestDuration {
    final durationInMinutes = _prefs.getInt(_settingContestDuration) ?? 0;
    return _limitContestDuration(durationInMinutes);
  }

  set contestDuration(int value) =>
      _prefs.setInt(_settingContestDuration, _limitContestDuration(value));

  PhonicType get phonicType =>
      _parsePhonicType(_prefs.getInt(_settingPhonicType));

  set phonicType(PhonicType value) =>
      _prefs.setInt(_settingPhonicType, value.index);

  TrainingDifficulty get difficulty =>
      TrainingDifficulty.fromId(_prefs.getString(_settingDifficulty));

  set difficulty(TrainingDifficulty value) =>
      _prefs.setString(_settingDifficulty, value.id);

  /// User-owned audio settings.  Effects only affect incoming stations; the
  /// operator's own CQ and messages remain clear.
  double get audioVolume => _prefs.getDouble(_settingAudioVolume) ?? 1.0;

  set audioVolume(double value) =>
      _prefs.setDouble(_settingAudioVolume, value.clamp(0.2, 1.2).toDouble());

  String binding(OperationAction action) =>
      _prefs.getString('$_settingKeyBindingPrefix${action.id}') ??
      action.defaultKey;

  Future<void> setBinding(OperationAction action, String key) =>
      _prefs.setString('$_settingKeyBindingPrefix${action.id}', key);

  List<TrainingRunReview> get sessionHistory =>
      (_prefs.getStringList(_settingSessionHistory) ?? const [])
          .map(TrainingRunReview.decode)
          .toList();

  void saveSessionReview(TrainingRunReview review) {
    final history = [
      review,
      ...sessionHistory,
    ].take(30).map((item) => item.encode()).toList();
    _prefs.setStringList(_settingSessionHistory, history);
  }

  int? get replaySeed => _prefs.getInt(_settingReplaySeed);

  set replaySeed(int? value) {
    if (value == null) {
      _prefs.remove(_settingReplaySeed);
    } else {
      _prefs.setInt(_settingReplaySeed, value);
    }
  }

  int _limitContestDuration(int durationInMinutes) {
    return min(durationInMinutes, maxDurationInMinutesPerRun);
  }

  PhonicType _parsePhonicType(int? value) {
    switch (value) {
      case 0:
        return PhonicType.standard;
      case 1:
        return PhonicType.location;
      case 2:
        return PhonicType.mixed;
      default:
        return PhonicType.standard;
    }
  }
}

const _settingContestId = 'setting_contest_id';
const _settingContestMode = 'setting_contest_mode';
const _settingStationCallsign = 'setting_station_callsign';
const _settingContestDuration = 'setting_contest_duration';
const _settingPhonicType = 'setting_phonic_type';
const _settingDifficulty = 'setting_difficulty';
const _settingAudioVolume = 'setting_audio_volume';
const _settingKeyBindingPrefix = 'setting_key_binding_';
const _settingSessionHistory = 'setting_session_history';
const _settingReplaySeed = 'setting_replay_seed';

enum OperationAction {
  cq('cq', 'CQ', 'F1'),
  exchange('exchange', 'EXCH', 'F2'),
  tu('tu', 'TU', 'F3'),
  myCall('my-call', '<my>', 'F4'),
  hisCall('his-call', '<his>', 'F5'),
  before('before', 'B4', 'F6'),
  again('again', 'AGN', 'F7'),
  noCopy('no-copy', 'NIL', 'F8');

  const OperationAction(this.id, this.label, this.defaultKey);
  final String id;
  final String label;
  final String defaultKey;
}
