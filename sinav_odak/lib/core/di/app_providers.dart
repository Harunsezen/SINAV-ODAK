/// Uygulama genelindeki Riverpod provider tanımları.
///
/// **Neden `core/di` altında?** Bu dosya daha önce `data/local/providers.dart`
/// konumundaydı ve `domain/services/recovery_service.dart`'ı import ediyordu.
/// Yani data katmanı domain'e bağımlı hale gelmiş, `providers -> recovery_service
/// -> database` şeklinde döngüsel bir bağımlılık oluşmuştu. Bağımlılık kurulumu
/// (DI) hiçbir katmana ait değildir; `core/di` bunun doğru yeridir.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/daos/goal_dao.dart';
import '../../data/local/daos/session_dao.dart';
import '../../data/local/daos/settings_dao.dart';
import '../../data/local/daos/stats_dao.dart';
import '../../data/local/daos/subject_dao.dart';
import '../../data/local/daos/wrong_item_dao.dart';
import '../../data/local/database.dart';
import '../../data/repositories/session_repository.dart';
import '../../application/recovery_service.dart';
import '../../application/schedule_writer.dart';
import '../../application/usecases/complete_onboarding.dart';
import '../../application/usecases/extend_break.dart';
import '../../application/usecases/finish_session.dart';
import '../../application/usecases/skip_break.dart';
import '../../application/usecases/start_session.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/session_schedule.dart';
import '../../domain/entities/session_state.dart';
import '../../domain/ports/session_activity_tracker.dart';
import '../../domain/ports/session_notifier.dart';
import '../../domain/services/schedule_resolver.dart';
import '../../services/background/lifecycle_tracker.dart';
import '../../services/notifications/local_session_notifier.dart';
import '../../services/notifications/notification_service.dart';
import '../utils/time.dart';
import '../utils/time.dart' as clock;

/// Uygulama boyunca TEK veritabanı örneği.
/// `main()` içinde `overrideWithValue` ile açılmış örnek verilir; testlerde
/// `AppDatabase.memory()` ile override edilir.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider main() içinde override edilmeli');
});

/// Oturum yazma orkestrasyonu (oturum + yanlış defteri + daily_stats).
final sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => SessionRepository(ref.watch(databaseProvider)));

/// Açılışta hesaplanan kurtarma sonucu. main() içinde override edilir.
final pendingRecoveryProvider = Provider<RecoveryResult>(
  (ref) => RecoveryResult.empty,
);

/// Kurtarma diyaloğunun tüketilip tüketilmediği (S18 / KARAR D2).
///
/// [pendingRecoveryProvider] açılışta hesaplanan **tek seferlik** bir
/// sonuçtur. Diyalog ana panel seviyesinde gösterilir; ana panel sekme
/// değişiminde yeniden kurulabildiği için "gösterildi" bilgisi widget
/// state'inde değil, provider seviyesinde tutulur — aksi halde kullanıcı
/// her sekme dönüşünde aynı diyalogla karşılaşırdı.
class RecoveryConsumedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void consume() => state = true;
}

final recoveryConsumedProvider =
    NotifierProvider<RecoveryConsumedNotifier, bool>(
  RecoveryConsumedNotifier.new,
);

/// Kurtarma orkestrasyonu. `main()` açılışta [RecoveryService.check] çağırır;
/// kurtarma diyaloğu ise kullanıcı kararını [RecoveryService.interruptNow] ile
/// uygular.
final recoveryServiceProvider = Provider<RecoveryService>(
  (ref) => RecoveryService(
    ref.watch(databaseProvider),
    ref.watch(sessionRepositoryProvider),
  ),
);

final settingsDaoProvider =
    Provider<SettingsDao>((ref) => ref.watch(databaseProvider).settingsDao);

final subjectDaoProvider =
    Provider<SubjectDao>((ref) => ref.watch(databaseProvider).subjectDao);

final sessionDaoProvider =
    Provider<SessionDao>((ref) => ref.watch(databaseProvider).sessionDao);

final statsDaoProvider =
    Provider<StatsDao>((ref) => ref.watch(databaseProvider).statsDao);

final goalDaoProvider =
    Provider<GoalDao>((ref) => ref.watch(databaseProvider).goalDao);

final wrongItemDaoProvider =
    Provider<WrongItemDao>((ref) => ref.watch(databaseProvider).wrongItemDao);

/// Ayarlar akışı — tema, net katsayısı, hedefler buradan okunur.
/// Satır yoksa otomatik yeniden oluşturur ve akışa devam eder.
/// Tema, net katsayısı ve hedefler buradan okunduğu için bu akışın
/// hataya düşmesi tüm UI'yı düşürüyordu.
final settingsStreamProvider = StreamProvider<UserSetting>((ref) async* {
  final dao = ref.watch(settingsDaoProvider);
  await for (final s in dao.watch()) {
    yield s ?? await dao.ensure();
  }
});

// ---------------------------------------------------------------------------
// Bildirim ve lifecycle (ALT GÖREV 2)
// ---------------------------------------------------------------------------

/// Bildirim altyapısı. `main()` içinde bir kez `initialize()` edilir.
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

/// Gerçek bildirim implementasyonu.
///
/// Test veya bildirimsiz çalıştırmada `NoopSessionNotifier` ile override
/// edilebilir; use-case'ler yalnızca [SessionNotifier] arayüzünü tanır.
final sessionNotifierProvider = Provider<SessionNotifier>(
  (ref) => LocalSessionNotifier(
    ref.watch(notificationServiceProvider),
    nowMsProvider: nowMs,
  ),
);

/// Uygulamadan çıkışları ölçen izleyici.
final activityTrackerProvider = Provider<SessionActivityTracker>(
  (ref) => LifecycleTracker(
    ref.watch(databaseProvider),
    nowMsProvider: nowMs,
  ),
);

// ---------------------------------------------------------------------------
// Use-case'ler
// ---------------------------------------------------------------------------

final scheduleWriterProvider = Provider<ScheduleWriter>(
  (ref) => ScheduleWriter(
    ref.watch(databaseProvider),
    ref.watch(sessionNotifierProvider),
  ),
);

final startSessionProvider = Provider<StartSessionUseCase>(
  (ref) => StartSessionUseCase(
    ref.watch(databaseProvider),
    ref.watch(sessionNotifierProvider),
    ref.watch(activityTrackerProvider),
  ),
);

final finishSessionProvider = Provider<FinishSessionUseCase>(
  (ref) => FinishSessionUseCase(
    ref.watch(databaseProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(sessionNotifierProvider),
    ref.watch(activityTrackerProvider),
  ),
);

final extendBreakProvider = Provider<ExtendBreakUseCase>(
  (ref) => ExtendBreakUseCase(
    ref.watch(databaseProvider),
    ref.watch(scheduleWriterProvider),
  ),
);

final completeOnboardingProvider = Provider<CompleteOnboardingUseCase>(
  (ref) => CompleteOnboardingUseCase(ref.watch(databaseProvider)),
);

final skipBreakProvider = Provider<SkipBreakUseCase>(
  (ref) => SkipBreakUseCase(
    ref.watch(databaseProvider),
    ref.watch(scheduleWriterProvider),
  ),
);

// ---------------------------------------------------------------------------
// Run akışı state'i (AG5: presentation katmanı data'ya doğrudan erişmesin
// diye bu provider'lar DI konteynerinde tutuluyor)
// ---------------------------------------------------------------------------

/// Aktif oturumun kimliği ve çizelgesi.
typedef ActiveSchedule = ({String sessionId, SessionSchedule schedule});

/// Zaman kaynağı.
///
/// Provider olarak tanımlanmasının tek sebebi **test edilebilirlik**:
/// widget testlerinde sabit epoch ile override edilir, böylece
/// `DateTime.now()`'a bağlı kalınmaz.
final clockProvider = Provider<int Function()>((ref) => clock.nowMs);

/// Aktif (`running`) oturum. Drift stream'i olduğu için her yazımda yenilenir.
final activeSessionProvider = StreamProvider<StudySession?>(
  (ref) => ref.watch(sessionDaoProvider).watchActiveSession(),
);

/// Aktif oturumun çizelgesi.
///
/// `scheduleJson` bozuksa `null` döner — UI çökmez, kurtarma akışı devreye
/// girer. Bu, `RecoveryService`'teki fallback ile aynı savunma.
final activeScheduleProvider = Provider<ActiveSchedule?>((ref) {
  final session = ref.watch(activeSessionProvider).valueOrNull;
  if (session == null) return null;
  try {
    final schedule = SessionSchedule.fromJson(
      jsonDecode(session.scheduleJson) as Map<String, dynamic>,
    );
    return (sessionId: session.id, schedule: schedule);
  } on Object {
    return null;
  }
});

/// **Sadece görsel** saniye vuruşu.
///
/// Bu ticker state'i İLERLETMEZ. Yalnızca [runStateProvider]'ın yeniden
/// değerlendirilmesini tetikler; hangi blokta olunduğu her seferinde
/// `ScheduleResolver.resolve(now)` ile baştan hesaplanır.
///
/// Ticker dursa, gecikse veya atlasa bile doğruluk bozulmaz — bu yüzden
/// sayaç `Timer` tabanlı bir mimari değildir.
final uiTickerProvider = StreamProvider.autoDispose<int>(
  (ref) => Stream<int>.periodic(const Duration(seconds: 1), (i) => i),
);

/// Aktif oturumun anlık durumu.
///
/// Doğruluk zinciri: `clock()` → `schedule` → `ScheduleResolver.resolve()`.
final runStateProvider = Provider<SessionState>((ref) {
  // Ticker yalnızca yeniden hesaplamayı tetikler; değeri kullanılmaz.
  ref.watch(uiTickerProvider);

  final active = ref.watch(activeScheduleProvider);
  if (active == null) return const SessionState.idle();

  return ScheduleResolver.resolve(
    sessionId: active.sessionId,
    schedule: active.schedule,
    nowMs: ref.watch(clockProvider)(),
  );
});

/// Yanlış defteri listesi — sekme başına bir akış.
///
/// `WrongItemView` bir data katmanı tipidir; ekranlar onu **tip çıkarımıyla**
/// tüketir, dolayısıyla `presentation` katmanı `data`'yı import etmez.
final wrongItemsProvider =
    StreamProvider.family<List<WrongItemView>, WrongItemStatus>(
  (ref, status) => ref.watch(wrongItemDaoProvider).watchByStatus(status),
);

/// Bir günün özeti (tebrik ekranındaki günlük ilerleme).
final dayStatsProvider = StreamProvider.family<DailyStat?, String>(
  (ref, dayKey) => ref.watch(statsDaoProvider).watchDay(dayKey),
);

/// Aktif oturumun ders ve konu adı.
///
/// Oturum sonu formu başlığında gösterilir. Presentation katmanı Drift
/// tiplerini isimlendirmeden tükettiği için ad çözümlemesi burada yapılır.
typedef ActiveLabels = ({String subjectName, String? topicName});

final activeSessionLabelsProvider =
    FutureProvider<ActiveLabels?>((ref) async {
  final session = ref.watch(activeSessionProvider).valueOrNull;
  if (session == null) return null;

  final dao = ref.watch(subjectDaoProvider);
  final subject = await dao.findSubject(session.subjectId);
  final topicId = session.topicId;
  final topic = topicId == null ? null : await dao.findTopic(topicId);

  return (subjectName: subject?.name ?? '', topicName: topic?.name);
});

// ---------------------------------------------------------------------------
// Katalog akışları (oturum kurulum ekranları için)
//
// Bu provider'lar Drift tiplerini (Subject, Topic, ActivityType) döndürüyor.
// Presentation katmanı `ref.watch(...)` ile TİP ÇIKARIMI kullanarak bunları
// tüketir; böylece ekranların data katmanını doğrudan import etmesi gerekmez.
// ---------------------------------------------------------------------------

/// Kullanıcının seçtiği sınav türü. Ayar satırı yoksa ensure() toparlar.
final examTypeProvider = Provider<ExamType>((ref) {
  return ref.watch(settingsStreamProvider).valueOrNull?.examType ??
      ExamType.yks;
});

/// Aktif sınav türüne ait, arşivlenmemiş dersler.
final subjectsProvider = StreamProvider<List<Subject>>((ref) {
  return ref.watch(subjectDaoProvider).watchSubjects(ref.watch(examTypeProvider));
});

/// Bir dersin arşivlenmemiş konuları.
final topicsProvider = StreamProvider.family<List<Topic>, String>(
  (ref, subjectId) => ref.watch(subjectDaoProvider).watchTopics(subjectId),
);

/// Çalışma türleri (Konu Anlatımı, Soru Çözümü, ...).
final activityTypesProvider = StreamProvider<List<ActivityType>>(
  (ref) => ref.watch(subjectDaoProvider).watchActivityTypes(),
);
