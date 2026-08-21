import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/l10n/format_l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/app_providers.dart';
import '../../core/errors/failures.dart';
import '../../core/router/routes.dart';
import '../../domain/entities/session_schedule.dart';
import '../../domain/entities/session_state.dart';
import '../../domain/services/net_calculator.dart';
import 'run_controller.dart';
import 'pending_finish_controller.dart';

/// S10 — Oturum Sonu Formu.
///
/// **Oturumun kaydedildiği TEK yer (KARAR D1).** RunScreen'deki "Bitir"
/// onayı oturumu kapatmaz; yalnızca [pendingFinishProvider]'a bitiş bağlamını
/// yazıp bu ekranı açar. Böylece soru sayıları ilk ve tek yazımda kaydedilir,
/// `daily_stats` bir kez hesaplanır.
///
/// **Bu ekranda REKLAM YOKTUR ve olmayacaktır.** Kullanıcı veri girerken
/// bölünmemeli; ürünün değişmez kurallarından biri. Reklam yalnızca kayıt
/// TAMAMLANDIKTAN sonra (tebrik ekranı) gösterilebilir.
///
/// Zaman `clockProvider` / [pendingFinishProvider] üzerinden gelir;
/// `DateTime.now()` çağrılmaz.
class SummaryForm extends ConsumerStatefulWidget {
  const SummaryForm({super.key});

  @override
  ConsumerState<SummaryForm> createState() => _SummaryFormState();
}

class _SummaryFormState extends ConsumerState<SummaryForm> {
  final _questionCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();

  int _questionCount = 0;
  int _correct = 0;
  int _wrong = 0;
  int _empty = 0;
  int? _mood;

  /// Kayıt sürerken form ekranda kalır: `finishSession` biter bitmez aktif
  /// oturum düşer ve [runStateProvider] `idle`'a döner. Bu bayrak olmasaydı
  /// kullanıcı, tebrik ekranına geçilene kadar "özetlenecek oturum yok"
  /// boş durumunu görürdü.
  bool _saving = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Tek oturumda girilebilecek en fazla soru sayısı.
  ///
  /// Üst sınır olmadan `999999` gibi bir giriş istatistikleri ve net
  /// hesabını saçmalaştırıyordu. 2000, deneme sınavı çözen bir öğrencinin
  /// gerçek üst ucunun (bir TYT+AYT günü ~240 soru) çok üzerinde; yani
  /// meşru kullanımı engellemiyor, yalnızca hatalı girişi kesiyor.
  static const int maxQuestions = 2000;

  /// Son girişte tavana kırpma yapıldı mı? Mesaj buna göre gösteriliyor.
  bool _questionsCapped = false;

  void _setQuestions(int value) {
    final clamped =
        value < 0 ? 0 : (value > maxQuestions ? maxQuestions : value);
    setState(() {
      _questionCount = clamped;
      _questionsCapped = value > maxQuestions;
    });
    final v = clamped;
    final text = v.toString();
    if (_questionCtrl.text != text) {
      _questionCtrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  /// [endMs] anına kadar gerçekleşen çalışma süresi — **yalnızca gösterim**.
  ///
  /// Kaydedilen süre her zaman `FinishSessionUseCase` içinde
  /// `ScheduleWriter.elapsedOf` ile hesaplanır; burada aynı sonucu üretmek
  /// kullanıcıya doğru rakamı göstermek içindir, kayda girmez.
  int _elapsedStudyS(SessionSchedule schedule, int endMs) {
    var total = 0;
    for (final b in schedule.blocks) {
      if (!b.isStudy) continue;
      total += (endMs - b.startMs).clamp(0, b.seconds * 1000) ~/ 1000;
    }
    return total;
  }

  Future<void> _save({
    required String sessionId,
    required PendingFinish pending,
  }) async {
    // dateKey oturumun BAŞLADIĞI güne yazılır; tebrik ekranı günlük
    // ilerlemeyi bu anahtardan okur.
    final dateKey = ref.read(activeSessionProvider).valueOrNull?.dateKey;

    setState(() => _saving = true);
    try {
      final focusScore = await ref.read(runControllerProvider).finish(
            sessionId: sessionId,
            early: pending.early,
            nowMs: pending.endMs,
            questionCount: _questionCount,
            correctCount: _correct,
            wrongCount: _wrong,
            emptyCount: _empty,
            mood: _mood,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );

      // Sıra önemli: kayıt sonucu YAZILMADAN yönlendirilirse router'ın aktif
      // oturum koruması /run/done'ı ana panele geri yollar.
      ref.read(savedResultProvider.notifier).set(
            sessionId: sessionId,
            focusScore: focusScore,
            dateKey: dateKey ?? '',
          );
      ref.read(pendingFinishProvider.notifier).clear();

      // Kayıt tamamlandı: ince dokunsal onay. `unawaited` — titreşim
      // motorunu beklemek yönlendirmeyi geciktirirdi; kaydın doğruluğu
      // titreşime bağlı değil.
      unawaited(ref.read(hapticGatewayProvider).success());

      if (mounted) context.go(Routes.runDone);
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kaynak `runStateProvider` DEĞİL, aktif oturumun kendisidir: erken
    // bitirmede çizelge hâlâ sürdüğü için state `inBlock`'tur, `summarizing`
    // değil. Forma yalnızca state'e bakarak karar verilseydi erken bitiren
    // kullanıcı boş ekran görürdü.
    final active = ref.watch(activeScheduleProvider);
    final pendingOrNull = ref.watch(pendingFinishProvider);
    final isSummarizing = ref.watch(runStateProvider) is SessionSummarizing;

    // Form iki yoldan açılır: çizelge kendiliğinden bitti (summarizing) ya da
    // kullanıcı "Bitir" onayını verdi (pendingFinish yazıldı). İkisi de yoksa
    // özetlenecek bir şey yok.
    if (active == null || (!isSummarizing && pendingOrNull == null)) {
      if (_saving) {
        return const Scaffold(
          key: Key('summary-saving'),
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        key: const Key('summary-empty'),
        body: Center(child: Text(L10n.of(context).summaryEmptyState)),
      );
    }

    final schedule = active.schedule;

    // Bitiş bağlamı normalde RunScreen tarafından yazılır. Doğrudan bu yola
    // girilirse (derin bağlantı, kurtarma) çizelgenin planlanan bitişi
    // varsayılır — erken bitirme yalnızca açık bir onaydan doğabilir.
    final pending =
        pendingOrNull ?? (early: false, endMs: schedule.plannedEndAtMs);

    final studyS = pending.early
        ? _elapsedStudyS(schedule, pending.endMs)
        : schedule.totalStudyS;

    final coefficient =
        ref.watch(settingsStreamProvider).valueOrNull?.netPenaltyCoefficient ??
            4.0;

    // Canlı net: doğrulama da domain'in kendisinden gelsin diye hesap
    // try/catch ile çağrılıyor. Aynı kural iki yerde yazılırsa biri
    // değiştiğinde diğeri sessizce yanlış kalır.
    double? net;
    String? invariantError;
    try {
      net = NetCalculator.calculate(
        questionCount: _questionCount,
        correctCount: _correct,
        wrongCount: _wrong,
        emptyCount: _empty,
        coefficient: coefficient,
        // Net süreden bağımsız: önizleme hız/soru-başına-süre göstermiyor.
        actualDurationS: 0,
      ).net;
    } on AppFailure catch (e) {
      invariantError = e.message;
    }

    final labels = ref.watch(activeSessionLabelsProvider).valueOrNull;
    final canSave = invariantError == null && !_saving;
    final l = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.summaryTitle),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        key: const Key('summary-form'),
        padding: const EdgeInsets.all(16),
        children: [
          _Header(labels: labels, studyS: studyS, breakS: schedule.totalBreakS),
          const SizedBox(height: 16),

          _QuestionCard(
            controller: _questionCtrl,
            capped: _questionsCapped,
            onQuick: (add) => _setQuestions(_questionCount + add),
            onReset: () => _setQuestions(0),
            onManual: (text) => _setQuestions(int.tryParse(text.trim()) ?? 0),
          ),
          const SizedBox(height: 16),

          _BreakdownCard(
            correct: _correct,
            wrong: _wrong,
            empty: _empty,
            onCorrect: (v) => setState(() => _correct = v),
            onWrong: (v) => setState(() => _wrong = v),
            onEmpty: (v) => setState(() => _empty = v),
            net: net,
            error: invariantError,
          ),
          const SizedBox(height: 16),

          _MoodCard(
            mood: _mood,
            onMood: (m) => setState(() => _mood = m),
            noteController: _noteCtrl,
          ),

          const SizedBox(height: 24),
          FilledButton(
            key: const Key('summary-save'),
            onPressed: canSave
                ? () => _save(sessionId: active.sessionId, pending: pending)
                : null,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.summarySave),
          ),
          const SizedBox(height: 8),

          // ADIM 6 UYARISI: bu ekrana reklam EKLENMEZ. Aşağıdaki metin
          // `summary_form_test.dart` içinde regresyon kalkanı olarak
          // aranıyor; kaldırılırsa test kırılır.
          Text(
            l.summaryNoAds,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Üst bilgi: ders · konu + süre.
class _Header extends StatelessWidget {
  const _Header({
    required this.labels,
    required this.studyS,
    required this.breakS,
  });

  final ActiveLabels? labels;
  final int studyS;
  final int breakS;

  @override
  Widget build(BuildContext context) {
    final subject = labels?.subjectName ?? '';
    final topic = labels?.topicName;
    final title =
        topic == null || topic.isEmpty ? subject : '$subject · $topic';

    return Card(
      key: const Key('summary-header'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    L10n.of(context).summaryDone,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 8),
              // Uzun ders/konu adı taşmasın: iki satırda kırpılıyor.
              Text(
                title,
                key: const Key('summary-subject'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              L10n.of(context)
                  .summaryStudy(L10n.of(context).durationShort(studyS)),
              key: const Key('summary-study'),
            ),
            Text(
              L10n.of(context)
                  .summaryBreak(L10n.of(context).durationShort(breakS)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soru sayacı: hızlı butonlar + elle giriş.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.controller,
    required this.capped,
    required this.onQuick,
    required this.onReset,
    required this.onManual,
  });

  final TextEditingController controller;

  /// Değer tavana kırpıldıysa alanın altında satır içi mesaj gösterilir.
  final bool capped;
  final void Function(int add) onQuick;
  final VoidCallback onReset;
  final void Function(String text) onManual;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.of(context).summaryQuestionsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('summary-q-plus5'),
                  onPressed: () => onQuick(5),
                  child: const Text('+5'),
                ),
                OutlinedButton(
                  key: const Key('summary-q-plus10'),
                  onPressed: () => onQuick(10),
                  child: const Text('+10'),
                ),
                OutlinedButton(
                  key: const Key('summary-q-plus20'),
                  onPressed: () => onQuick(20),
                  child: const Text('+20'),
                ),
                TextButton(
                  key: const Key('summary-q-reset'),
                  onPressed: onReset,
                  child: Text(L10n.of(context).summaryReset),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('summary-q-field'),
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: L10n.of(context).summaryQuestionCount,
                border: const OutlineInputBorder(),
              ),
              onChanged: onManual,
            ),
            // Kırpma sessiz olmamalı: kullanıcı 5000 yazıp 2000 görünce
            // neyin olduğunu bilmeli. Diyalog AÇILMAZ — veri girerken
            // akışı bölmek bu ekranın değişmez kuralına aykırı.
            if (capped) ...[
              const SizedBox(height: 6),
              Text(
                L10n.of(context).summaryQuestionCapped,
                key: const Key('summary-q-capped'),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Doğru / yanlış / boş sayaçları + canlı net önizlemesi.
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.correct,
    required this.wrong,
    required this.empty,
    required this.onCorrect,
    required this.onWrong,
    required this.onEmpty,
    required this.net,
    required this.error,
  });

  final int correct;
  final int wrong;
  final int empty;
  final ValueChanged<int> onCorrect;
  final ValueChanged<int> onWrong;
  final ValueChanged<int> onEmpty;

  /// Doğrulama hatası varsa `null`.
  final double? net;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.of(context).summaryBreakdownTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _Counter(
              label: L10n.of(context).summaryCorrect,
              slug: 'correct',
              color: AppColors.correct,
              value: correct,
              onChanged: onCorrect,
            ),
            _Counter(
              label: L10n.of(context).summaryWrong,
              slug: 'wrong',
              color: AppColors.wrong,
              value: wrong,
              onChanged: onWrong,
            ),
            _Counter(
              label: L10n.of(context).summaryEmpty,
              slug: 'empty',
              color: AppColors.empty,
              value: empty,
              onChanged: onEmpty,
            ),
            const Divider(height: 24),
            if (error != null)
              Text(
                error!,
                key: const Key('summary-invariant-error'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${L10n.of(context).summaryNet}  '),
                  Text(
                    L10n.of(context).netText(net ?? 0),
                    key: const Key('summary-net'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// `[−] sayı [+]` biçiminde tek satırlık sayaç.
class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.slug,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String slug;
  final Color color;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        IconButton(
          key: Key('summary-$slug-dec'),
          // Negatife düşmek domain'de ValidationFailure; buton seviyesinde
          // engellenerek kullanıcı hiç hata görmeden korunuyor.
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            key: Key('summary-$slug-value'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          key: Key('summary-$slug-inc'),
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// Duygu seçici (1..5) + opsiyonel not.
class _MoodCard extends StatelessWidget {
  const _MoodCard({
    required this.mood,
    required this.onMood,
    required this.noteController,
  });

  final int? mood;
  final ValueChanged<int> onMood;
  final TextEditingController noteController;

  static const _emojis = ['😖', '😕', '😐', '🙂', '😄'];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.of(context).summaryMoodTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    key: Key('summary-mood-$i'),
                    onPressed: () => onMood(i),
                    isSelected: mood == i,
                    icon: Text(
                      _emojis[i - 1],
                      style: TextStyle(fontSize: mood == i ? 30 : 22),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('summary-note'),
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: L10n.of(context).summaryNote,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
