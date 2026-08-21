/// Uygulama genelindeki Riverpod provider tanımları.
///
/// **Neden `core/di` altında?** Bu dosya daha önce `data/local/providers.dart`
/// konumundaydı ve `domain/services/recovery_service.dart`'ı import ediyordu.
/// Yani data katmanı domain'e bağımlı hale gelmiş, `providers -> recovery_service
/// -> database` şeklinde döngüsel bir bağımlılık oluşmuştu. Bağımlılık kurulumu
/// (DI) hiçbir katmana ait değildir; `core/di` bunun doğru yeridir.
library;

import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_locale.dart';
import '../../domain/services/notification_planner.dart';
import '../../data/local/daos/achievement_dao.dart';
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
import '../../application/usecases/build_report.dart';
import '../../application/usecases/discard_session.dart';
import '../../application/usecases/extend_break.dart';
import '../../application/usecases/finish_session.dart';
import '../../application/usecases/skip_break.dart';
import '../../application/usecases/start_session.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/notification_prefs.dart';
import '../../domain/entities/session_schedule.dart';
import '../../domain/entities/session_state.dart';
import '../../domain/ports/haptic_gateway.dart';
import '../../domain/ports/screen_wake_gateway.dart';
import '../../domain/ports/session_activity_tracker.dart';
import '../../domain/ports/session_notifier.dart';
import '../../domain/services/schedule_resolver.dart';
import '../../domain/services/streak_calculator.dart';
import '../../services/background/lifecycle_tracker.dart';
import '../../services/background/system_haptic_gateway.dart';
import '../../services/background/wakelock_screen_gateway.dart';
import '../../services/notifications/local_session_notifier.dart';
import '../../services/notifications/foreground_notification_guard.dart';
import '../../services/notifications/notification_service.dart';
import '../utils/date_key.dart';
import '../utils/time.dart';
import '../utils/time.dart' as clock;
import '../../application/settings_controller.dart';
import '../../application/usecases/export_sessions.dart';
import '../../application/usecases/recompute_nets.dart';
import '../../domain/ports/share_gateway.dart';
import '../../services/export/file_share_gateway.dart';
import '../../services/report/pdf_report_builder.dart';

/// Uygulama boyunca TEK veritabanı örneği.
/// `main()` içinde `overrideWithValue` ile açılmış örnek verilir; testlerde
/// `AppDatabase.memory()` ile override edilir.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider main() içinde override edilmeli');
});

/// Oturum yazma orkestrasyonu (oturum + yanlış defteri + daily_stats).
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);

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
    // Tercihler KURULUM ANINDA okunuyor (`ref.read`), çünkü kullanıcı
    // oturum sürerken ayarı değiştirebilir ve bir sonraki bildirim
    // kurulumu güncel tercihi görmeli.
    prefsReader: () => ref.read(notificationPrefsProvider),
    // Metinler de kurulum anında okunuyor: kullanıcı oturum sürerken dili
    // değiştirebilir ve bir sonraki bildirim yeni dilde kurulmalı.
    stringsReader: () => ref.read(notificationStringsProvider),
  ),
);

/// Uygulamanın **o anki** arayüz dili.
///
/// Ayar okunamazsa Türkçe: uygulama v1.1'de Türkçeydi ve okunamayan bir
/// ayar yüzünden dil değiştirmek en kötü varsayılan olurdu.
final appLanguageProvider = Provider<AppLanguage>((ref) {
  return ref.watch(settingsStreamProvider).valueOrNull?.language ??
      AppLanguage.tr;
});

/// Widget ağacı dışından okunabilen çeviri paketi.
///
/// `L10n.of(context)` bir `BuildContext` istiyor; bildirim kuran servisin
/// elinde context yok. `lookupL10n` aynı üretilmiş sınıfı context'siz
/// veriyor — iki ayrı çeviri kaynağı OLUŞMUYOR.
final l10nProvider = Provider<L10n>((ref) {
  return lookupL10n(
    AppLocale.resolve(
      ref.watch(appLanguageProvider),
      platformLocale: PlatformDispatcher.instance.locale,
    ),
  );
});

/// Bildirim metinleri, arayüzle AYNI dilden.
final notificationStringsProvider = Provider<NotificationStrings>((ref) {
  final l = ref.watch(l10nProvider);
  return NotificationStrings(
    sessionDoneTitle: l.notifSessionDoneTitle,
    sessionDoneBody: l.notifSessionDoneBody,
    breakTitle: l.notifBreakTitle,
    breakOverTitle: l.notifBreakOverTitle,
    breakBody: l.notifBreakBody,
    breakOverBody: l.notifBreakOverBody,
  );
});

/// CSV sütun başlıkları, arayüzle AYNI dilden.
final csvHeadersProvider = Provider<List<String>>((ref) {
  final l = ref.watch(l10nProvider);
  return [
    l.csvDate,
    l.csvStart,
    l.csvSubject,
    l.csvTopic,
    l.csvType,
    l.csvPlannedMin,
    l.csvStudiedMin,
    l.csvBreakMin,
    l.csvQuestions,
    l.csvCorrect,
    l.csvWrong,
    l.csvBlank,
    l.csvNet,
    l.csvFocusScore,
    l.csvMood,
    l.csvStatus,
    l.csvNote,
  ];
});

/// Ekran kilidi. **Varsayılan Noop**: `wakelock_plus` platform kanalı
/// istiyor ve testte `MissingPluginException` fırlatıyor. `main()` gerçek
/// cihazda [WakelockScreenGateway] ile override eder.
final screenWakeGatewayProvider =
    Provider<ScreenWakeGateway>((ref) => const NoopScreenWakeGateway());

/// Ekran şu an açık TUTULMALI mı?
///
/// İki koşul: kullanıcı ayarı açık **ve** aktif bir oturum var. Ayarın tek
/// başına ekranı sürekli açık tutması pili boşuna tüketirdi.
///
/// FAZ 8 öncesinde `keepScreenOn` ayarı yalnızca veritabanına yazılıyor,
/// **hiçbir yerde okunmuyordu**: kullanıcı açıyor, çalışma sırasında ekran
/// yine kapanıyordu.
final shouldKeepScreenOnProvider = Provider<bool>((ref) {
  final wants =
      ref.watch(settingsStreamProvider).valueOrNull?.keepScreenOn ?? false;
  final hasActive = ref.watch(activeSessionProvider).valueOrNull != null;
  return wants && hasActive;
});

/// Dokunsal geri bildirim. **Varsayılan Noop**: `HapticFeedback` platform
/// kanalı istiyor ve testte akışı bekletiyor. `main()` gerçek cihazda
/// [SystemHapticGateway] ile override eder — o da kullanıcının **titreşim
/// ayarına kapılıdır**.
final hapticGatewayProvider =
    Provider<HapticGateway>((ref) => const NoopHapticGateway());

/// Ayar satırından okunan bildirim tercihleri.
///
/// Ayar akışı henüz gelmediyse **varsayılan** kullanılır: burada `false`'a
/// düşmek, ilk açılışta bildirimleri sessizce kapatmak olurdu.
final notificationPrefsProvider = Provider<NotificationPrefs>((ref) {
  final s = ref.watch(settingsStreamProvider).valueOrNull;
  if (s == null) return NotificationPrefs.defaults;
  return NotificationPrefs(
    enabled: s.notificationEnabled,
    sound: s.soundEnabled,
    vibration: s.vibrationEnabled,
  );
});

/// Kullanıcı aktif oturumu **bilerek** arka plana aldı mı? (v1.1 / FAZ 1.1)
///
/// v1.0'da aktif oturum varken router her yolu `/run`'a çeviriyordu:
/// kullanıcı ana panele, istatistiklere, ayarlara **hiç** gidemiyordu.
/// Gerekçe "kazara çıkmayı önlemek"ti ama sonuç, kullanıcıyı kendi
/// uygulamasında hapsetmekti.
///
/// Artık çıkış **bilinçli bir onaydan** geçiyor ve bu bayrak o onayı
/// taşıyor. **"Pause yok" kuralı bozulmuyor:** sayaç duvar saatiyle
/// işlemeye devam eder, oturum arka planda sürer; değişen tek şey
/// kullanıcının başka ekranlara bakabilmesi.
class SessionMinimizedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Onaylı çıkış: router artık `/run` dışına izin verir.
  void minimize() => state = true;

  /// Oturuma dönüldü veya oturum bitti.
  void restore() => state = false;
}

final sessionMinimizedProvider =
    NotifierProvider<SessionMinimizedNotifier, bool>(
  SessionMinimizedNotifier.new,
);

/// Ana panelde "oturum devam ediyor" şeridi gösterilsin mi?
///
/// Küçültülmüş **ve** hâlâ aktif bir oturum varsa. Bu şerit olmadan
/// küçültme bir çıkmaz olurdu: kullanıcı oturumdan çıkar ve geri dönecek
/// bir kapı bulamazdı.
final showActiveSessionBannerProvider = Provider<bool>((ref) {
  final minimized = ref.watch(sessionMinimizedProvider);
  final active = ref.watch(activeSessionProvider).valueOrNull;
  return minimized && active != null;
});

/// Ön plandayken sistem bildirimlerini susturan bekçi (v1.0.2 hotfix).
///
/// **Neden var:** blok/mola bitişleri oturum başlarken mutlak zamana
/// kuruluyor ve kurulduktan sonra uygulamanın ön planda olup olmadığından
/// habersiz tetikleniyor. Ürün kuralı ise ön plandayken kullanıcıyı
/// rahatsız etmemeyi ve **kesinlikle uygulama dışına atmamayı** gerektiriyor
/// (bkz. HOTFIX.md).
///
/// `app.dart` bunu `watch` ediyor; okunmazsa provider hiç oluşmaz ve bekçi
/// çalışmaz.
final foregroundNotificationGuardProvider =
    Provider<ForegroundNotificationGuard>((ref) {
  final guard = ForegroundNotificationGuard(
    notifier: ref.watch(sessionNotifierProvider),
    // `read`: yaşam döngüsü olayı geldiği ANDAKİ oturum okunmalı.
    readActive: () => ref.read(activeScheduleProvider),
  );
  guard.start();
  ref.onDispose(guard.stop);
  return guard;
});

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

/// Rapor verisi toplayıcı (FAZ 3.1).
final buildReportProvider = Provider<BuildReportUseCase>(
  (ref) => BuildReportUseCase(ref.watch(databaseProvider)),
);

/// PDF çizici. Saf biçimlendirme; ağ yok.
final pdfReportBuilderProvider =
    Provider<PdfReportBuilder>((ref) => const PdfReportBuilder());

/// Aktif oturumu kaydetmeden siler (FAZ 1.3 — "Bitir → Sil").
final discardSessionProvider = Provider<DiscardSessionUseCase>(
  (ref) => DiscardSessionUseCase(
    ref.watch(sessionDaoProvider),
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

/// Bugünün gün anahtarı.
///
/// `todayKey()` doğrudan çağrılsaydı `DateTime.now()`'a bağlı kalırdık ve
/// ana panel testleri gerçek takvim gününü okurdu. [clockProvider] üzerinden
/// türetiliyor; testlerde sabit epoch ile deterministik.
final todayKeyProvider = Provider<String>(
  (ref) => dateKeyOfMs(ref.watch(clockProvider)()),
);

/// Ana panelde GÖSTERİLECEK streak.
///
/// DB'deki ham `currentStreak` değil: zincir koptuysa kullanıcıya 0 görünür.
/// DB'ye dokunulmaz — streak yalnızca kayıt anında yazılır, okuma anında
/// değil (aksi halde uygulamayı açmak veriyi değiştirirdi).
final displayStreakProvider = Provider<int>((ref) {
  final s = ref.watch(settingsStreamProvider).valueOrNull;
  if (s == null) return 0;
  return StreakCalculator.displayStreak(
    lastStudyDate: s.lastStudyDate,
    currentStreak: s.currentStreak,
    today: ref.watch(todayKeyProvider),
  );
});

/// Son kapanmış oturumlar (ana panel listesi).
final recentSessionsProvider = StreamProvider<List<StudySession>>(
  (ref) => ref.watch(sessionDaoProvider).watchRecent(),
);

/// Aktif hedefler.
final activeGoalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalDaoProvider).watchActive(),
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

final activeSessionLabelsProvider = FutureProvider<ActiveLabels?>((ref) async {
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
  return ref
      .watch(subjectDaoProvider)
      .watchSubjects(ref.watch(examTypeProvider));
});

/// Bir dersin arşivlenmemiş konuları.
final topicsProvider = StreamProvider.family<List<Topic>, String>(
  (ref, subjectId) => ref.watch(subjectDaoProvider).watchTopics(subjectId),
);

/// Çalışma türleri (Konu Anlatımı, Soru Çözümü, ...).
final activityTypesProvider = StreamProvider<List<ActivityType>>(
  (ref) => ref.watch(subjectDaoProvider).watchActivityTypes(),
);

// ---------------------------------------------------------------------------
// FAZ 7A — Ayarlar ve istatistik
// ---------------------------------------------------------------------------

/// Net katsayısı değiştiğinde geçmiş netleri yeniden hesaplar.
final recomputeNetsProvider = Provider<RecomputeNetsUseCase>(
  (ref) => RecomputeNetsUseCase(ref.watch(databaseProvider)),
);

/// Ayar yazma işlemlerinin tek kapısı.
///
/// Ekranlar `UserSettingsCompanion` kurmak yerine bunu çağırıyor; Drift'in
/// üretilmiş tipleri `presentation` katmanına sızmıyor (G4).
final settingsControllerProvider = Provider<SettingsController>(
  (ref) => SettingsController(ref.watch(databaseProvider)),
);

/// Oturumları CSV olarak paylaşır.
final exportSessionsProvider = Provider<ExportSessionsUseCase>(
  (ref) => ExportSessionsUseCase(
    ref.watch(databaseProvider),
    ref.watch(shareGatewayProvider),
  ),
);

/// Dosya paylaşımı (CSV dışa aktarma).
///
/// **Varsayılan Noop**: `share_plus` ve `path_provider` platform kanalı
/// istiyor, testte çağrılırsa akış hiç tamamlanmıyor. `main()` gerçek
/// cihazda [FileShareGateway] ile override eder.
final shareGatewayProvider =
    Provider<ShareGateway>((ref) => const NoopShareGateway());

/// İstatistik ekranının seçili aralığı.
enum StatsRange { week, month }

final statsRangeProvider = StateProvider<StatsRange>((_) => StatsRange.week);

/// Seçili aralığın (başlangıç, bitiş) sınırları.
///
/// Saat [clockProvider]'dan geliyor: `DateTime.now()` doğrudan çağrılsaydı
/// istatistik ekranı test edilemezdi.
final statsBoundsProvider = Provider<({DateTime from, DateTime to})>((ref) {
  final now = DateTime.fromMillisecondsSinceEpoch(ref.watch(clockProvider)());
  final today = DateTime(now.year, now.month, now.day);
  return switch (ref.watch(statsRangeProvider)) {
    StatsRange.week => (from: startOfWeek(today), to: today),
    StatsRange.month => (from: startOfMonth(today), to: today),
  };
});

/// Seçili aralığın günlük satırları — grafiği besler.
final statsDailyProvider = StreamProvider<List<DailyStat>>((ref) {
  final b = ref.watch(statsBoundsProvider);
  return ref.watch(statsDaoProvider).watchRange(b.from, b.to);
});

/// Seçili aralığın toplamı.
///
/// `statsDailyProvider`'ı izliyor: yeni bir oturum kaydedilince günlük
/// satırlar değişiyor ve özet de tazelenmeli. Yalnızca sınırları izleseydi
/// kullanıcı oturum bitirdikten sonra özet kartları eski değerde kalırdı.
final statsSummaryProvider = FutureProvider<StatsSummary>((ref) async {
  ref.watch(statsDailyProvider);
  final b = ref.watch(statsBoundsProvider);
  return ref.watch(statsDaoProvider).summaryFor(b.from, b.to);
});

/// Ders kırılımı — dağılım çubuklarını besler.
final statsBreakdownProvider =
    FutureProvider<List<SubjectBreakdownRow>>((ref) async {
  ref.watch(statsDailyProvider);
  final b = ref.watch(statsBoundsProvider);
  return ref.watch(statsDaoProvider).subjectBreakdown(b.from, b.to);
});

/// Gün × saat yoğunluğu (FAZ 3.2 ısı haritası).
///
/// `counts[gün][saat]` — gün 0=Pazartesi. Oturumun BAŞLAMA saatini
/// sayıyor; süreyi saatlere bölmek daha doğru olurdu ama bir oturum
/// nadiren saat sınırını aşıyor ve bölme, "hangi saatte çalışmayı
/// seviyorum" sorusunu bulanıklaştırırdı.
final statsHourHeatmapProvider = FutureProvider<List<List<int>>>((ref) async {
  ref.watch(statsDailyProvider);
  final b = ref.watch(statsBoundsProvider);
  final sessions = await ref.watch(sessionDaoProvider).rangeSessions(
        b.from,
        b.to,
      );

  final grid = [for (var d = 0; d < 7; d++) List<int>.filled(24, 0)];
  for (final s in sessions) {
    final dt = DateTime.fromMillisecondsSinceEpoch(s.startedAt);
    // `DateTime.weekday` 1=Pazartesi..7=Pazar.
    grid[dt.weekday - 1][dt.hour]++;
  }
  return grid;
});

/// En çok yanlış yapılan konular.
final statsWeakestProvider = FutureProvider<
        List<({String topicName, String subjectName, int wrongCount})>>(
    (ref) async {
  ref.watch(statsDailyProvider);
  final b = ref.watch(statsBoundsProvider);
  return ref.watch(statsDaoProvider).weakestTopics(b.from, b.to);
});

/// Bir dersin konuları — arşivlenmişler DAHİL (katalog yönetimi için).
final allTopicsProvider = StreamProvider.family<List<Topic>, String>(
  (ref, subjectId) => ref
      .watch(subjectDaoProvider)
      .watchTopics(subjectId, includeArchived: true),
);

/// Dersler — arşivlenmişler DAHİL (katalog yönetimi için).
final allSubjectsProvider = StreamProvider<List<Subject>>(
  (ref) => ref
      .watch(subjectDaoProvider)
      .watchSubjects(ref.watch(examTypeProvider), includeArchived: true),
);

/// Çalışma türleri — arşivlenmişler DAHİL.
final allActivityTypesProvider = StreamProvider<List<ActivityType>>(
  (ref) =>
      ref.watch(subjectDaoProvider).watchActivityTypes(includeArchived: true),
);

// ---------------------------------------------------------------------------
// FAZ 7B — Takvim, hedefler, rozetler
// ---------------------------------------------------------------------------

/// "Bugün" — saat DIŞARIDAN geliyor, `DateTime.now()` değil.
final calendarTodayProvider = Provider<DateTime>((ref) {
  final now = DateTime.fromMillisecondsSinceEpoch(ref.watch(clockProvider)());
  return DateTime(now.year, now.month, now.day);
});

/// Takvimde görüntülenen ay (ayın ilk günü).
final calendarMonthProvider = StateProvider<DateTime>((ref) {
  final t = ref.watch(calendarTodayProvider);
  return DateTime(t.year, t.month);
});

/// Görüntülenen ayın günlük satırları.
final calendarDaysProvider = StreamProvider<List<DailyStat>>((ref) {
  final m = ref.watch(calendarMonthProvider);
  // Ayın son günü: bir sonraki ayın "0."ıncı günü.
  final last = DateTime(m.year, m.month + 1, 0);
  return ref.watch(statsDaoProvider).watchRange(m, last);
});

/// Tüm hedefler (aktifler üstte).
final allGoalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalDaoProvider).watchAll(),
);

final achievementDaoProvider = Provider<AchievementDao>(
  (ref) => ref.watch(databaseProvider).achievementDao,
);

/// Henüz görülmemiş rozetler — tebrik ekranı bunları kutluyor.
///
/// Rozetler `SessionRepository.save()` yolunda sessizce açılıyordu;
/// kullanıcı Ayarlar > Rozetler'e girmedikçe kazandığından haberi olmuyordu.
final unseenAchievementsProvider =
    FutureProvider<List<Achievement>>((ref) async {
  final all = await ref.watch(achievementsProvider.future);
  return all.where((a) => !a.isSeen).toList();
});

/// Açılmış rozetler.
final achievementsProvider = StreamProvider<List<Achievement>>(
  (ref) => ref.watch(achievementDaoProvider).watchAll(),
);
