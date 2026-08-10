import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/app_providers.dart';
import '../../domain/entities/session_schedule.dart';
import '../../domain/entities/session_state.dart';

/// Run akışının aksiyonları.
///
/// Use-case'lerin kendileri `core/di/app_providers.dart` içinde tanımlı
/// (DI konteyneri); burada yalnızca UI'ın çağıracağı ince bir katman var.
class RunController {
  const RunController(this._ref);

  final Ref _ref;

  /// Oturum başlatır ve kimliğini döner.
  Future<String> start({
    required String sessionId,
    required SessionSchedule schedule,
    required String subjectId,
    String? topicId,
    required String activityTypeId,
  }) {
    return _ref.read(startSessionProvider)(
      sessionId: sessionId,
      schedule: schedule,
      subjectId: subjectId,
      topicId: topicId,
      activityTypeId: activityTypeId,
    );
  }

  /// Oturumu kapatır ve odak skorunu döner.
  ///
  /// [early] `true` ise kullanıcı "Oturumu Bitir" dedi; onay UI'da alınır.
  Future<int?> finish({
    required String sessionId,
    required bool early,
    int questionCount = 0,
    int correctCount = 0,
    int wrongCount = 0,
    int emptyCount = 0,
    int? mood,
    String? note,
  }) {
    return _ref.read(finishSessionProvider)(
      sessionId: sessionId,
      nowMs: _ref.read(clockProvider)(),
      early: early,
      questionCount: questionCount,
      correctCount: correctCount,
      wrongCount: wrongCount,
      emptyCount: emptyCount,
      mood: mood,
      note: note,
    );
  }

  /// Aktif molayı uzatır. Limit aşımında `PlanFailure` fırlar.
  Future<void> extendBreak({int addS = 300}) async {
    final state = _ref.read(runStateProvider);
    if (state is! SessionInBreak) return;

    await _ref.read(extendBreakProvider)(
      sessionId: state.sessionId,
      breakBlockIndex: state.blockIndex,
      addS: addS,
    );
  }

  /// Aktif molayı erken bitirir.
  ///
  /// Tam bitiş saniyesinde basılırsa `ValidationFailure` fırlar; bu durumda
  /// resolver zaten sonraki bloğa geçmiş olur, hata sessizce yutulur.
  Future<void> skipBreak() async {
    final state = _ref.read(runStateProvider);
    if (state is! SessionInBreak) return;

    try {
      await _ref.read(skipBreakProvider)(
        sessionId: state.sessionId,
        breakBlockIndex: state.blockIndex,
        nowMs: _ref.read(clockProvider)(),
      );
    } on Object {
      // Mola tam o anda bittiyse yapacak bir şey yok.
    }
  }

  /// Kalan uzatma hakkı (5 dakikalık adım sayısı).
  int remainingExtensions() {
    final state = _ref.read(runStateProvider);
    if (state is! SessionInBreak) return 0;
    const maxSteps = 600 ~/ 300;
    return (maxSteps - state.extensionsUsed).clamp(0, maxSteps);
  }
}

final runControllerProvider =
    Provider<RunController>(RunController.new);
