import 'dart:math';
import 'dart:typed_data';

/// A practice profile is intentionally independent from a contest definition.
/// This keeps one ruleset usable in a clean beginner exercise and in a noisy
/// pile-up without duplicating the scoring implementation.
enum TrainingMode {
  run('run', 'Run', 'Callers answer your CQ in sequence'),
  searchAndPounce(
    'search-and-pounce',
    'S&P',
    'Find and work one station at a time',
  ),
  pileup('pileup', 'Pile-up', 'Choose the target from overlapping callers');

  const TrainingMode(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;

  static TrainingMode fromId(String? id) => TrainingMode.values.firstWhere(
    (mode) => mode.id == id,
    orElse: () => TrainingMode.run,
  );
}

enum TrainingDifficulty {
  beginner('beginner', 'Beginner', 1.0, 0.0, 0.0, 0),
  standard('standard', 'Standard', 1.08, 0.10, 0.05, 1),
  advanced('advanced', 'Advanced', 1.18, 0.22, 0.16, 2);

  const TrainingDifficulty(
    this.id,
    this.label,
    this.playbackRate,
    this.noiseAmount,
    this.fadingAmount,
    this.pileupCallers,
  );

  final String id;
  final String label;
  final double playbackRate;
  final double noiseAmount;
  final double fadingAmount;
  final int pileupCallers;

  static TrainingDifficulty fromId(String? id) =>
      TrainingDifficulty.values.firstWhere(
        (difficulty) => difficulty.id == id,
        orElse: () => TrainingDifficulty.standard,
      );
}

class AudioTrainingProfile {
  const AudioTrainingProfile({
    required this.playbackRate,
    required this.noiseAmount,
    required this.fadingAmount,
    required this.volume,
    required this.seed,
  });

  final double playbackRate;
  final double noiseAmount;
  final double fadingAmount;
  final double volume;
  final int seed;

  factory AudioTrainingProfile.fromDifficulty({
    required TrainingDifficulty difficulty,
    required double volume,
    required int seed,
  }) => AudioTrainingProfile(
    playbackRate: difficulty.playbackRate,
    noiseAmount: difficulty.noiseAmount,
    fadingAmount: difficulty.fadingAmount,
    volume: volume,
    seed: seed,
  );
}

/// Applies deterministic, deliberately modest effects to remote-station PCM.
/// Input/output is mono 16-bit little-endian PCM at the project's 24 kHz rate.
class AudioTrainingEffects {
  static Uint8List apply(Uint8List pcm, AudioTrainingProfile profile) {
    if (pcm.isEmpty) return pcm;

    final rateAdjusted = _resample(pcm, profile.playbackRate);
    final bytes = Uint8List.fromList(rateAdjusted);
    final data = ByteData.sublistView(bytes);
    final random = Random(profile.seed ^ bytes.length);
    const sampleRate = 24000.0;

    for (var offset = 0; offset + 1 < bytes.length; offset += 2) {
      final sample = data.getInt16(offset, Endian.little);
      final second = (offset / 2) / sampleRate;
      final fade =
          1 - profile.fadingAmount * (0.5 + 0.5 * sin(second * pi * 2));
      final noise = (random.nextDouble() * 2 - 1) * 32767 * profile.noiseAmount;
      final adjusted = (sample * fade + noise) * profile.volume;
      data.setInt16(
        offset,
        adjusted.clamp(-32768, 32767).round(),
        Endian.little,
      );
    }
    return bytes;
  }

  static Uint8List _resample(Uint8List pcm, double rate) {
    if (rate <= 1.001) return Uint8List.fromList(pcm);
    final inputSamples = pcm.length ~/ 2;
    final outputSamples = max(1, inputSamples ~/ rate);
    final input = ByteData.sublistView(pcm);
    final output = Uint8List(outputSamples * 2);
    final outputData = ByteData.sublistView(output);
    for (var index = 0; index < outputSamples; index++) {
      final source = min(inputSamples - 1, (index * rate).round());
      outputData.setInt16(
        index * 2,
        input.getInt16(source * 2, Endian.little),
        Endian.little,
      );
    }
    return output;
  }
}
