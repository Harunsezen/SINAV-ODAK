import 'package:drift/drift.dart';

import '../../data/local/database.dart';
import '../../domain/entities/enums.dart';

/// Onboarding'i tamamlar ve kullanıcının ilk tercihlerini yazar.
///
/// **Neden use-case?** Onboarding ekranı doğrudan `UserSettingsCompanion`
/// kullansaydı presentation katmanı Drift'e bağımlı olurdu. Bu sınıf o
/// bağımlılığı application katmanında tutuyor.
class CompleteOnboardingUseCase {
  const CompleteOnboardingUseCase(this._db);

  final AppDatabase _db;

  /// [personalizedAdsConsent] KVKK/GDPR açık rızası.
  ///
  /// Varsayılanı `false` ve **öyle kalmalı**: rıza alınmadan kişiselleştirilmiş
  /// reklam gösterilemez. Onboarding'in rıza adımı bunu açıkça `true`
  /// yaptığında buradan geçer; parametre verilmezse mevcut değere DOKUNULMAZ.
  Future<void> call({
    ExamType? examType,
    int? dailyGoalMinutes,
    int? dailyGoalQuestions,
    bool? personalizedAdsConsent,
  }) async {
    await _db.settingsDao.ensure();
    await _db.settingsDao.patchSettings(
      UserSettingsCompanion(
        onboardingCompleted: const Value(true),
        examType: examType == null ? const Value.absent() : Value(examType),
        dailyGoalMinutes: dailyGoalMinutes == null
            ? const Value.absent()
            : Value(dailyGoalMinutes),
        dailyGoalQuestions: dailyGoalQuestions == null
            ? const Value.absent()
            : Value(dailyGoalQuestions),
        personalizedAdsConsent: personalizedAdsConsent == null
            ? const Value.absent()
            : Value(personalizedAdsConsent),
      ),
    );
  }
}
