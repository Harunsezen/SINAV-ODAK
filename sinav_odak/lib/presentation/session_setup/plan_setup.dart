import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/app_providers.dart';
import '../../core/errors/failures.dart';
import '../../core/router/routes.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/session_schedule.dart';
import '../../domain/services/schedule_builder.dart';
import 'setup_controller.dart';

enum PlanMode { preset, custom, endTime }

/// Hazır plan şablonları: (çalışma dk, mola dk).
const _presets = <(int, int)>[
  (25, 5),
  (40, 10),
  (50, 10),
  (60, 15),
  (80, 15),
  (120, 20),
];

/// S07 — Plan Ayar.
///
/// Üç mod da aynı domain servisini kullanır (`ScheduleBuilder`); bu ekran
/// yalnızca girdileri toplar ve **canlı önizleme** gösterir. Doğrulama
/// domain'de: blok < 10 dk, bitiş geçmişte, mola süreyi yiyor gibi durumlar
/// `PlanFailure` olarak gelir ve BAŞLAT devre dışı kalır.
class PlanSetup extends ConsumerStatefulWidget {
  const PlanSetup({super.key});

  @override
  ConsumerState<PlanSetup> createState() => _PlanSetupState();
}

class _PlanSetupState extends ConsumerState<PlanSetup> {
  PlanMode _mode = PlanMode.preset;

  // Hazır
  int _presetIndex = 0;
  int _cycles = 3;

  // Özel
  int _totalStudyMinutes = 100;
  int _customBreakCount = 3;
  int _customBreakMinutes = 5;
  bool _lastBreakLong = false;

  // Bitiş saati
  int? _endHour;
  int _endMinute = 0;
  int _endBreakCount = 1;
  int _endBreakMinutes = 10;

  bool _starting = false;

  /// Seçili moda göre çizelgeyi kurar. Hata mesajı döner (null = sorun yok).
  ({ScheduleBuildResult? result, String? error}) _build() {
    final nowMs = ref.read(clockProvider)();
    try {
      switch (_mode) {
        case PlanMode.preset:
          final (work, brk) = _presets[_presetIndex];
          return (
            result: ScheduleBuilder.fromPreset(
              startAtMs: nowMs,
              workMinutes: work,
              breakMinutes: brk,
              cycles: _cycles,
            ),
            error: null
          );
        case PlanMode.custom:
          return (
            result: ScheduleBuilder.fromSpecial(
              startAtMs: nowMs,
              totalStudyMinutes: _totalStudyMinutes,
              breakCount: _customBreakCount,
              breakMinutes: _customBreakMinutes,
              lastBreakLong: _lastBreakLong,
            ),
            error: null
          );
        case PlanMode.endTime:
          final hour = _endHour;
          if (hour == null) {
            return (result: null, error: L10n.of(context).planPickEnd);
          }
          final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
          // KARAR K7: geçmişte kalan saat otomatik yarına TAŞINMAZ.
          final end = DateTime(now.year, now.month, now.day, hour, _endMinute);
          return (
            result: ScheduleBuilder.fromEndTime(
              nowMs: nowMs,
              endAtMs: end.millisecondsSinceEpoch,
              breakCount: _endBreakCount,
              breakMinutes: _endBreakMinutes,
            ),
            error: null
          );
      }
    } on AppFailure catch (e) {
      return (result: null, error: e.message);
    }
  }

  Future<void> _start(SessionSchedule schedule) async {
    final setup = ref.read(setupProvider);
    if (!setup.isReadyForPlan) {
      context.go(Routes.sessionSubject);
      return;
    }

    setState(() => _starting = true);
    try {
      await ref.read(startSessionProvider)(
        sessionId: const Uuid().v4(),
        schedule: schedule,
        subjectId: setup.subjectId!,
        topicId: setup.topicId,
        activityTypeId: setup.activityTypeId!,
      );
      // R2: seçimler yeni akışa sızmasın.
      ref.read(setupProvider.notifier).reset();
      if (mounted) context.go(Routes.run);
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(setupProvider);
    final built = _build();
    final schedule = built.result?.schedule;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).planTitle),
        leading: IconButton(
          key: const Key('setup-back-plan'),
          icon: const Icon(Icons.arrow_back),
          tooltip: L10n.of(context).commonBack,
          // `context.go` yığını DEĞİŞTİRDİĞİ için `Navigator.canPop()`
          // daima false ve AppBar'ın otomatik geri tuşu HİÇ çizilmiyordu
          // (v1.0'da dört kurulum adımının hiçbirinde geri yoktu).
          // Bu yüzden önceki adım açıkça veriliyor.
          onPressed: () => context.go(Routes.sessionType),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            [
              setup.subjectName,
              setup.topicName,
              setup.activityTypeName,
            ].whereType<String>().join(' · '),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 16),
          SegmentedButton<PlanMode>(
            segments: [
              ButtonSegment(
                value: PlanMode.preset,
                label: Text(L10n.of(context).planPreset),
              ),
              ButtonSegment(
                value: PlanMode.custom,
                label: Text(L10n.of(context).planCustom),
              ),
              ButtonSegment(
                value: PlanMode.endTime,
                label: Text(L10n.of(context).planByEnd),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          if (_mode == PlanMode.preset) ..._presetControls(),
          if (_mode == PlanMode.custom) ..._customControls(),
          if (_mode == PlanMode.endTime) ..._endTimeControls(),
          const Divider(height: 32),
          if (built.error != null)
            Card(
              key: const Key('plan-error'),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(built.error!),
              ),
            ),
          if (built.result != null) ...[
            for (final w in built.result!.warnings)
              Card(
                key: Key('plan-warning-${w.name}'),
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_warningText(w)),
                ),
              ),
            _Preview(schedule: schedule!),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('plan-start'),
            onPressed:
                (schedule == null || _starting) ? null : () => _start(schedule),
            child: Text(
              _starting
                  ? L10n.of(context).planStarting
                  : L10n.of(context).planStart,
            ),
          ),
        ],
      ),
    );
  }

  String _warningText(ScheduleWarning w) => switch (w) {
        ScheduleWarning.blockTooLong => L10n.of(context).planLongBlockWarning,
        ScheduleWarning.lastBreakLongApplied =>
          L10n.of(context).planLastBreakDoubled,
      };

  List<Widget> _presetControls() => [
        Text(L10n.of(context).planTemplate),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < _presets.length; i++)
              ChoiceChip(
                key: Key('preset-$i'),
                label: Text('${_presets[i].$1}+${_presets[i].$2}'),
                selected: _presetIndex == i,
                onSelected: (_) => setState(() => _presetIndex = i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Stepper(
          key: const Key('preset-cycles'),
          label: L10n.of(context).planCycles,
          value: _cycles,
          min: 1,
          max: 8,
          onChanged: (v) => setState(() => _cycles = v),
        ),
      ];

  List<Widget> _customControls() => [
        _Stepper(
          key: const Key('custom-total'),
          label: L10n.of(context).planTotalMinutes,
          value: _totalStudyMinutes,
          min: 10,
          max: 480,
          step: 5,
          onChanged: (v) => setState(() => _totalStudyMinutes = v),
        ),
        _Stepper(
          key: const Key('custom-breaks'),
          label: L10n.of(context).planBreakCount,
          value: _customBreakCount,
          min: 0,
          max: 10,
          onChanged: (v) => setState(() => _customBreakCount = v),
        ),
        _Stepper(
          key: const Key('custom-break-min'),
          label: L10n.of(context).planBreakMinutes,
          value: _customBreakMinutes,
          min: 1,
          max: 30,
          onChanged: (v) => setState(() => _customBreakMinutes = v),
        ),
        SwitchListTile(
          key: const Key('custom-last-long'),
          title: Text(L10n.of(context).planLastBreakLong),
          value: _lastBreakLong,
          onChanged: (v) => setState(() => _lastBreakLong = v),
        ),
      ];

  List<Widget> _endTimeControls() => [
        Row(
          children: [
            Text(L10n.of(context).planEndTime),
            const SizedBox(width: 16),
            DropdownButton<int>(
              key: const Key('end-hour'),
              value: _endHour,
              hint: Text(L10n.of(context).planHour),
              items: [
                for (var h = 0; h < 24; h++)
                  DropdownMenuItem(
                    value: h,
                    child: Text(h.toString().padLeft(2, '0')),
                  ),
              ],
              onChanged: (v) => setState(() => _endHour = v),
            ),
            const Text(' : '),
            DropdownButton<int>(
              key: const Key('end-minute'),
              value: _endMinute,
              items: const [
                DropdownMenuItem(value: 0, child: Text('00')),
                DropdownMenuItem(value: 15, child: Text('15')),
                DropdownMenuItem(value: 30, child: Text('30')),
                DropdownMenuItem(value: 45, child: Text('45')),
              ],
              onChanged: (v) => setState(() => _endMinute = v ?? 0),
            ),
          ],
        ),
        _Stepper(
          key: const Key('end-breaks'),
          label: L10n.of(context).planBreakCount,
          value: _endBreakCount,
          min: 0,
          max: 8,
          onChanged: (v) => setState(() => _endBreakCount = v),
        ),
        _Stepper(
          key: const Key('end-break-min'),
          label: L10n.of(context).planBreakMinutes,
          value: _endBreakMinutes,
          min: 1,
          max: 30,
          onChanged: (v) => setState(() => _endBreakMinutes = v),
        ),
      ];
}

/// Canlı önizleme: blok şeridi, toplam süre, bitiş anı.
class _Preview extends StatelessWidget {
  const _Preview({required this.schedule});

  final SessionSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final end = DateTime.fromMillisecondsSinceEpoch(schedule.plannedEndAtMs);
    final hh = end.hour.toString().padLeft(2, '0');
    final mm = end.minute.toString().padLeft(2, '0');

    return Card(
      key: const Key('plan-preview'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schedule.blocks
                  .map((b) => '${b.seconds ~/ 60}${b.isStudy ? "" : "m"}')
                  .join(' · '),
              key: const Key('plan-preview-blocks'),
            ),
            const SizedBox(height: 8),
            Text(
              L10n.of(context)
                  .planStudyTotal(formatDurationShort(schedule.totalStudyS)),
            ),
            Text(
              L10n.of(context)
                  .summaryBreak(formatDurationShort(schedule.totalBreakS)),
            ),
            Text(
              L10n.of(context).planEstimatedEnd('$hh:$mm'),
              key: const Key('plan-preview-end'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    super.key,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value - step >= min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 44,
          child: Text('$value', textAlign: TextAlign.center),
        ),
        IconButton(
          onPressed: value + step <= max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
