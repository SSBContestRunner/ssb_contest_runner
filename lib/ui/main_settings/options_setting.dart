import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ssb_runner/audio/audio_loader.dart';
import 'package:ssb_runner/common/constants.dart';
import 'package:ssb_runner/settings/app_settings.dart';
import 'package:ssb_runner/training/training_profile.dart';
import 'package:ssb_runner/ui/main_settings/main_settings.dart';

class _Options {
  const _Options({
    required this.mode,
    required this.duration,
    required this.phonicType,
    required this.difficulty,
    required this.volume,
  });
  final TrainingMode mode;
  final int duration;
  final PhonicType phonicType;
  final TrainingDifficulty difficulty;
  final double volume;
}

class _OptionsCubit extends Cubit<_Options> {
  _OptionsCubit(this._settings)
    : super(
        _Options(
          mode: TrainingMode.fromId(_settings.contestModeId),
          duration: _settings.contestDuration,
          phonicType: _settings.phonicType,
          difficulty: _settings.difficulty,
          volume: _settings.audioVolume,
        ),
      );
  final AppSettings _settings;
  void setMode(TrainingMode? value) {
    if (value != null) {
      _settings.contestModeId = value.id;
      _emit(mode: value);
    }
  }

  void setDifficulty(TrainingDifficulty? value) {
    if (value != null) {
      _settings.difficulty = value;
      _emit(difficulty: value);
    }
  }

  void setDuration(String input) {
    final value = (int.tryParse(input) ?? 0)
        .clamp(0, maxDurationInMinutesPerRun)
        .toInt();
    _settings.contestDuration = value;
    _emit(duration: value);
  }

  void setPhonic(PhonicType? value) {
    if (value != null) {
      _settings.phonicType = value;
      _emit(phonicType: value);
    }
  }

  void setVolume(double value) {
    _settings.audioVolume = value;
    _emit(volume: value);
  }

  void _emit({
    TrainingMode? mode,
    int? duration,
    PhonicType? phonicType,
    TrainingDifficulty? difficulty,
    double? volume,
  }) => emit(
    _Options(
      mode: mode ?? state.mode,
      duration: duration ?? state.duration,
      phonicType: phonicType ?? state.phonicType,
      difficulty: difficulty ?? state.difficulty,
      volume: volume ?? state.volume,
    ),
  );
}

class OptionsSetting extends StatelessWidget {
  const OptionsSetting({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => _OptionsCubit(context.read()),
    child: BlocBuilder<_OptionsCubit, _Options>(
      builder: (context, state) {
        final enabled = !context.watch<MainSettingsCubit>().state;
        final cubit = context.read<_OptionsCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _menu<TrainingMode>(
                    enabled: enabled,
                    label: 'Training mode',
                    value: state.mode,
                    entries: TrainingMode.values
                        .map(
                          (it) => DropdownMenuEntry(value: it, label: it.label),
                        )
                        .toList(),
                    onSelected: cubit.setMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: 'Practice duration in minutes',
                    child: TextFormField(
                      enabled: enabled,
                      initialValue: state.duration.toString(),
                      key: ValueKey(state.duration),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      onChanged: cubit.setDuration,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Duration',
                        suffixText: 'min',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _menu<TrainingDifficulty>(
              enabled: enabled,
              label: 'Difficulty',
              value: state.difficulty,
              entries: TrainingDifficulty.values
                  .map((it) => DropdownMenuEntry(value: it, label: it.label))
                  .toList(),
              onSelected: cubit.setDifficulty,
            ),
            const SizedBox(height: 12),
            _menu<PhonicType>(
              enabled: enabled,
              label: 'Phonic type',
              value: state.phonicType,
              entries: const [
                DropdownMenuEntry(
                  value: PhonicType.standard,
                  label: 'Standard',
                ),
                DropdownMenuEntry(
                  value: PhonicType.location,
                  label: 'Location',
                ),
                DropdownMenuEntry(value: PhonicType.mixed, label: 'Mixed'),
              ],
              onSelected: cubit.setPhonic,
            ),
            const SizedBox(height: 4),
            Semantics(
              label: 'Incoming station audio volume',
              value: '${(state.volume * 100).round()} percent',
              child: Slider(
                value: state.volume,
                min: 0.2,
                max: 1.2,
                divisions: 10,
                label: 'Incoming audio ${(state.volume * 100).round()}%',
                onChanged: enabled ? cubit.setVolume : null,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: enabled
                    ? () => showDialog<void>(
                        context: context,
                        builder: (_) => const _KeyBindingsDialog(),
                      )
                    : null,
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('Customize function keys'),
              ),
            ),
            if (context.read<AppSettings>().replaySeed != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    context.read<AppSettings>().replaySeed = null;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'The next session will use a new random seed.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Clear replay seed'),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _SessionHistoryDialog(),
                ),
                icon: const Icon(Icons.history),
                label: const Text('Review past sessions'),
              ),
            ),
          ],
        );
      },
    ),
  );
  Widget _menu<T>({
    required bool enabled,
    required String label,
    required T value,
    required List<DropdownMenuEntry<T>> entries,
    required void Function(T?) onSelected,
  }) => Semantics(
    label: label,
    child: DropdownMenu<T>(
      enabled: enabled,
      expandedInsets: EdgeInsets.zero,
      initialSelection: value,
      label: Text(label),
      dropdownMenuEntries: entries,
      onSelected: onSelected,
    ),
  );
}

class _KeyBindingsDialog extends StatefulWidget {
  const _KeyBindingsDialog();
  @override
  State<_KeyBindingsDialog> createState() => _KeyBindingsDialogState();
}

class _KeyBindingsDialogState extends State<_KeyBindingsDialog> {
  late final AppSettings settings;
  late final Map<OperationAction, String> bindings;
  @override
  void initState() {
    super.initState();
    settings = context.read();
    bindings = {
      for (final action in OperationAction.values)
        action: settings.binding(action),
    };
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Function keys'),
    content: SizedBox(
      width: 360,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final action in OperationAction.values)
            DropdownButtonFormField<String>(
              initialValue: bindings[action],
              decoration: InputDecoration(labelText: action.label),
              items: List.generate(
                8,
                (index) => DropdownMenuItem(
                  value: 'F${index + 1}',
                  child: Text('F${index + 1}'),
                ),
              ),
              onChanged: (key) {
                if (key != null) setState(() => bindings[action] = key);
              },
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (bindings.values.toSet().length != bindings.length) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Each command needs a different function key.'),
              ),
            );
            return;
          }
          for (final entry in bindings.entries) {
            settings.setBinding(entry.key, entry.value);
          }
          Navigator.pop(context);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _SessionHistoryDialog extends StatelessWidget {
  const _SessionHistoryDialog();
  @override
  Widget build(BuildContext context) {
    final sessions = context.read<AppSettings>().sessionHistory;
    return AlertDialog(
      title: const Text('Past sessions'),
      content: SizedBox(
        width: 440,
        child: sessions.isEmpty
            ? const Text('No completed sessions yet.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: sessions.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, index) {
                  final review = sessions[index];
                  return Semantics(
                    label:
                        '${review.metadata.contestName}, ${(review.accuracy * 100).toStringAsFixed(1)} percent accuracy',
                    child: ListTile(
                      onTap: () {
                        final messenger = ScaffoldMessenger.of(context);
                        final settings = context.read<AppSettings>();
                        settings
                          ..replaySeed = review.metadata.seed
                          ..contestId = review.metadata.contestId
                          ..contestModeId = review.metadata.modeId
                          ..difficulty = TrainingDifficulty.fromId(
                            review.metadata.difficultyId,
                          );
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Next session will replay seed ${review.metadata.seed}.',
                            ),
                          ),
                        );
                      },
                      title: Text(
                        '${review.metadata.contestName} · ${review.metadata.modeId}',
                      ),
                      subtitle: Text(
                        '${review.qsoCount} QSOs · ${(review.accuracy * 100).toStringAsFixed(1)}% · ${review.qsosPerHour.toStringAsFixed(1)}/h · seed ${review.metadata.seed}',
                      ),
                      trailing: Text('${review.score} pts'),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
