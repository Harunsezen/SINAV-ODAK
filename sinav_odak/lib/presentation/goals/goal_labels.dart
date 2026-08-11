import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/entities/enums.dart';

/// Hedef tipinin ekrandaki adı (ARB'den).
String goalTypeLabel(L10n l, GoalType type) => switch (type) {
      GoalType.dailyMinutes => l.goalTypeDailyMinutes,
      GoalType.weeklyMinutes => l.goalTypeWeeklyMinutes,
      GoalType.dailyQuestions => l.goalTypeDailyQuestions,
      GoalType.weeklyQuestions => l.goalTypeWeeklyQuestions,
      GoalType.subjectMinutes => l.goalTypeSubjectMinutes,
      GoalType.topicCompletion => l.goalTypeTopicCompletion,
      GoalType.net => l.goalTypeNet,
      GoalType.streak => l.goalTypeStreak,
    };

/// Hedefin BİRİMİ.
///
/// **`GoalProgressCalculator`'ın birim sözleşmesiyle aynı olmak ZORUNDA:**
/// süre hedefleri DAKİKA cinsindendir (hesap saniyeyi dakikaya çeviriyor).
/// Burada "saat" yazmak, 240'lık bir hedefi "240 saat" gibi göstermek olurdu.
String goalUnitLabel(L10n l, GoalType type) => switch (type) {
      GoalType.dailyMinutes ||
      GoalType.weeklyMinutes ||
      GoalType.subjectMinutes =>
        l.goalsUnitMinutes,
      GoalType.dailyQuestions ||
      GoalType.weeklyQuestions =>
        l.goalsUnitQuestions,
      GoalType.topicCompletion => l.goalsUnitTopics,
      GoalType.net => l.goalsUnitNet,
      GoalType.streak => l.goalsUnitDays,
    };
