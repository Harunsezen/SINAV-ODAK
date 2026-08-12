import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/app_router.dart';
import 'package:sinav_odak/core/theme/app_theme.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/presentation/settings/settings_screen.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';

import '../unit/usecase_helpers.dart';

/// QA turu için ortak altyapı.
///
/// **Neden ayrı dosya:** gezinti (`full_walk_test`) ve görüntü
/// (`screenshots_test`) turları aynı veritabanı tohumunu ve aynı uygulama
/// kurulumunu kullanmalı; iki yerde tutulsaydı biri değiştiğinde diğeri
/// sessizce farklı bir uygulamayı test ederdi.

/// Gerçek font yükleme sonucu.
///
/// Ekran görüntüleri font olmadan "Ahem" ile alınırsa tüm metinler siyah
/// kutuya dönüşür ve görsel denetim anlamını yitirir; bu yüzden sonucu
/// raporlayabilmek için durum döndürülüyor.
class FontLoadResult {
  const FontLoadResult({required this.loaded, required this.detail});

  final bool loaded;
  final String detail;
}

/// Flutter SDK'sının `material_fonts` klasöründen gerçek Roboto ve
/// MaterialIcons fontlarını yükler.
///
/// Yol `FLUTTER_ROOT`'tan çözülüyor; sabit yazmak başka makinede kırılırdı.
/// Bulunamazsa test **düşmez**, Ahem ile devam eder ve durum rapora yazılır.
Future<FontLoadResult> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) {
    return const FontLoadResult(
      loaded: false,
      detail: 'FLUTTER_ROOT tanımlı değil — Ahem fontu kullanıldı',
    );
  }

  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) {
    return FontLoadResult(
      loaded: false,
      detail: '${dir.path} yok — Ahem fontu kullanıldı',
    );
  }

  Future<bool> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final f in files) {
      final file = File('${dir.path}/$f');
      if (!file.existsSync()) continue;
      loader.addFont(
        file.readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
      any = true;
    }
    if (!any) return false;
    await loader.load();
    return true;
  }

  final roboto = await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Medium.ttf',
  ]);
  final icons = await load('MaterialIcons', ['MaterialIcons-Regular.otf']);

  if (!roboto && !icons) {
    return const FontLoadResult(
      loaded: false,
      detail: 'font dosyaları okunamadı — Ahem fontu kullanıldı',
    );
  }
  return FontLoadResult(
    loaded: true,
    detail: 'Roboto${roboto ? "" : " (yok)"} + '
        'MaterialIcons${icons ? "" : " (yok)"} yüklendi',
  );
}

/// QA veritabanı tohumları.
abstract final class QaSeed {
  /// Onboarding tamamlanmış, hiç veri girilmemiş kullanıcı.
  static Future<void> emptyUser(AppDatabase db) async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(onboardingCompleted: Value(true)),
    );
  }

  /// Bir süredir kullanan öğrenci: oturumlar, yanlışlar, hedef, rozet.
  ///
  /// Tarihler `t0`'a (2025-08-06) göre sabit; `DateTime.now()` yok.
  static Future<void> activeUser(AppDatabase db) async {
    await emptyUser(db);
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(
        currentStreak: Value(5),
        longestStreak: Value(9),
        lastStudyDate: Value('2025-08-06'),
      ),
    );

    for (final (i, day) in const [
      '2025-08-04',
      '2025-08-05',
      '2025-08-06',
    ].indexed) {
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 'qa_s$i',
              dateKey: day,
              startedAt: t0 + i * 3600000,
              plannedDurationS: 2880,
              subjectId: subjectId,
              topicId: const Value(topicId),
              activityTypeId: activityId,
              status: SessionStatus.completed,
              scheduleJson: '{}',
              actualDurationS: Value(2400 + i * 600),
              totalBreakS: const Value(300),
              questionCount: Value(30 + i * 10),
              correctCount: Value(20 + i * 8),
              wrongCount: Value(8 - i * 2),
              emptyCount: const Value(2),
              net: Value(18.0 + i * 4),
              focusScore: Value(78 + i * 5),
              mood: const Value(4),
              endedAt: Value(t0 + i * 3600000 + 2400000),
            ),
          );
      await db.statsDao.recomputeDay(day);
    }

    await db.wrongItemDao.addManual(
      id: 'qa_w1',
      subjectId: subjectId,
      topicId: topicId,
      note: 'Zincir kuralı karıştı',
    );
    await db.wrongItemDao.addManual(
      id: 'qa_w2',
      subjectId: subjectId,
      note: 'Limit — belirsizlik durumları',
    );

    await db.goalDao.createGoal(
      id: 'qa_g1',
      type: GoalType.dailyMinutes,
      target: 240,
    );
    await db.goalDao.setProgress('qa_g1', 120);
    await db.goalDao.createGoal(
      id: 'qa_g2',
      type: GoalType.dailyQuestions,
      target: 50,
    );
    await db.goalDao.setProgress('qa_g2', 50);
    await db.goalDao.setStatus('qa_g2', GoalStatus.completed);

    await db.achievementDao.unlock(code: 'first_session', unlockedAtMs: t0);
    await db.achievementDao.unlock(code: 'streak_3', unlockedAtMs: t0);
    await db.achievementDao.markSeen('first_session');
    await db.achievementDao.markSeen('streak_3');
  }

  /// Aşırı uzun adlar — metin taşması denetimi için.
  static Future<void> longNames(AppDatabase db) async {
    await db.subjectDao.renameSubject(
      subjectId,
      // Şema sınırı 60 karakter; TAM sınırda test ediyoruz.
      'Matematik ve İleri Analitik Geometri Uygulamaları Dersi II',
      '#4F5BD5',
    );
    await db.subjectDao.renameTopic(
      topicId,
      // Şema sınırı 120 karakter.
      'Türev Alma Kuralları, Zincir Kuralı, Kapalı Fonksiyonların Türevi ve '
      'Yüksek Mertebeden Türev Uygulamaları Konusu',
    );
  }
}

/// QA için gerçek router'lı uygulama kurulumu.
///
/// Reklam, paylaşım, titreşim ve ekran kilidi kapıları **varsayılan
/// Noop** kalıyor: QA turu platform kanalına dokunmamalı.
Future<ProviderContainer> pumpQaApp(
  WidgetTester tester,
  AppDatabase db, {
  Size size = const Size(430, 932),
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) async {
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => t0),
      sessionNotifierProvider
          .overrideWithValue(FakeNotifier() as SessionNotifier),
      activityTrackerProvider
          .overrideWithValue(FakeTracker() as SessionActivityTracker),
      uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
    ],
  );
  addTearDown(container.dispose);
  // TÜM ekran akışları ÖNCEDEN ısıtılıyor.
  //
  // Isıtılmazsa ekranlar `loading` dalında `CircularProgressIndicator`
  // gösteriyor; o da sonsuz dönen bir animasyon olduğu için
  // `pumpAndSettle` ASLA dönmüyor ve QA turu takılıyordu.
  await container.read(settingsStreamProvider.future);
  await container.read(activeSessionProvider.future);
  await container.read(subjectsProvider.future);
  await container.read(activityTypesProvider.future);
  await container.read(recentSessionsProvider.future);
  await container.read(statsDailyProvider.future);
  await container.read(calendarDaysProvider.future);
  await container.read(allGoalsProvider.future);
  await container.read(allSubjectsProvider.future);
  await container.read(allActivityTypesProvider.future);
  await container.read(achievementsProvider.future);
  await container.read(wrongItemsProvider(WrongItemStatus.active).future);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: qaRepaintKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme:
              brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          routerConfig: container.read(appRouterProvider),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Ekran görüntüsü alınacak sınır.
///
/// `MaterialApp`'in kendi kök render nesnesi `RenderRepaintBoundary`
/// DEĞİL; `toImage` için ağacı açıkça sarmak gerekiyor.
const qaRepaintKey = Key('qa-repaint-boundary');

/// Router'a QA turundan erişim (doğrudan rota açmak için).
final appRouterProviderForQa = appRouterProvider;

/// Ayarlar ekranını DOĞRUDAN kurar.
///
/// **Neden router üzerinden değil:** `/settings` route'u
/// `settingsPageFor(debug: kDebugMode)` çağırıyor ve testler debug modda
/// koştuğu için geliştirme aracını (`DbHealthPage`) seçiyor (KARAR D4/K3).
/// Release'te görülen gerçek Ayarlar ekranını gezmek için ekran doğrudan
/// kuruluyor.
Future<ProviderContainer> pumpQaSettings(
  WidgetTester tester,
  AppDatabase db, {
  Size size = const Size(430, 3000),
}) async {
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => t0),
      uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(settingsStreamProvider.future);
  await container.read(activeSessionProvider.future);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Gezintide bulunulan yol.
String currentRoute(ProviderContainer c) =>
    c.read(appRouterProvider).routerDelegate.currentConfiguration.uri.toString();
