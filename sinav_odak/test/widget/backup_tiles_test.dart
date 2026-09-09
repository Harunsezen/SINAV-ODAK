import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/backup_file_gateway.dart';
import 'package:sinav_odak/domain/ports/share_gateway.dart';
import 'package:sinav_odak/presentation/settings/widgets/backup_tiles.dart';

import '../unit/usecase_helpers.dart';

class CapturingShare implements ShareGateway {
  String? content;
  bool succeed = true;

  @override
  Future<bool> shareText({
    required String content,
    required String fileName,
    String? subject,
  }) async {
    this.content = content;
    return succeed;
  }

  @override
  Future<bool> shareBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? subject,
  }) async =>
      true;
}

/// Kullanıcının seçtiği dosyayı taklit eden kapı.
class FakePicker implements BackupFileGateway {
  FakePicker([this.text]);
  String? text;

  @override
  Future<String?> pickBackupText() async => text;
}

/// v1.3 — YEDEKLE / GERİ YÜKLE arayüzü.
///
/// Kırmızı çizgi: **geri yükleme onaysız çalışmamalı.** Mevcut veriyi
/// siliyor; yanlışlıkla dokunan kullanıcı aylarca biriktirdiği geçmişi
/// kaybederdi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CapturingShare share;
  late FakePicker picker;

  setUp(() {
    db = newDb();
    share = CapturingShare();
    picker = FakePicker();
  });
  tearDown(() async => db.close());

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        shareGatewayProvider.overrideWithValue(share as ShareGateway),
        backupFileGatewayProvider
            .overrideWithValue(picker as BackupFileGateway),
        appVersionProvider.overrideWithValue('1.3.0+6'),
      ],
    );
    addTearDown(c.dispose);
    await c.read(settingsStreamProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(body: BackupTiles()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> seedOne() async {
    await db.settingsDao.ensure();
    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: 'x1',
            dateKey: '2025-08-06',
            startedAt: t0,
            plannedDurationS: 600,
            subjectId: subjectId,
            activityTypeId: activityId,
            status: SessionStatus.completed,
            scheduleJson: '{}',
          ),
        );
  }

  testWidgets('YEDEK AL: tek dokunuş, onay istemiyor', (tester) async {
    // Yedek almak yıkıcı değil; sürtünme eklemek kullanıcıyı yedek
    // almaktan caydırırdı.
    await seedOne();
    await pump(tester);

    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pumpAndSettle();

    expect(share.content, isNotNull);
    expect(share.content, contains('sinav_odak_backup'));
    expect(find.byKey(const Key('backup-export-snack')), findsOneWidget);
  });

  testWidgets('paylaşım iptal edilirse BAŞARI mesajı ÇIKMIYOR', (tester) async {
    await seedOne();
    share.succeed = false;
    await pump(tester);

    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pumpAndSettle();

    expect(find.text('Yedek paylaşılamadı.'), findsOneWidget);
  });

  testWidgets('GERİ YÜKLE: ONAY olmadan veri değişmiyor', (tester) async {
    await seedOne();
    await pump(tester);

    // Önce gerçek bir yedek üret, sonra onu seçtir.
    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pumpAndSettle();
    picker.text = share.content;

    // Yedek alındıktan SONRA yeni bir oturum eklendi; geri yükleme
    // iptal edilirse bu oturum DURMALI.
    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: 'sonradan',
            dateKey: '2025-08-07',
            startedAt: t0,
            plannedDurationS: 600,
            subjectId: subjectId,
            activityTypeId: activityId,
            status: SessionStatus.completed,
            scheduleJson: '{}',
          ),
        );

    await tester.tap(find.byKey(const Key('backup-import')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('backup-restore-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-restore-cancel')));
    await tester.pumpAndSettle();

    expect(
      await db.sessionDao.findById('sonradan'),
      isNotNull,
      reason: 'VAZGEÇ veriye dokunmamalı',
    );
  });

  testWidgets('GERİ YÜKLE: onaylanınca yedek yazılıyor', (tester) async {
    await seedOne();
    await pump(tester);

    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pumpAndSettle();
    picker.text = share.content;

    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: 'sonradan',
            dateKey: '2025-08-07',
            startedAt: t0,
            plannedDurationS: 600,
            subjectId: subjectId,
            activityTypeId: activityId,
            status: SessionStatus.completed,
            scheduleJson: '{}',
          ),
        );

    await tester.tap(find.byKey(const Key('backup-import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-restore-confirm')));
    await tester.pumpAndSettle();

    expect(
      await db.sessionDao.findById('sonradan'),
      isNull,
      reason: 'geri yükleme DEĞİŞTİRİR',
    );
    expect(await db.sessionDao.findById('x1'), isNotNull);
    expect(find.byKey(const Key('backup-restore-snack')), findsOneWidget);
  });

  testWidgets('dosya seçilmezse SESSİZCE duruluyor', (tester) async {
    // Bilerek vazgeçen kullanıcıyı uyarıyla azarlamak yanlış.
    await seedOne();
    await pump(tester);
    picker.text = null;

    await tester.tap(find.byKey(const Key('backup-import')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('backup-restore-dialog')), findsNothing);
    expect(find.byKey(const Key('backup-error-snack')), findsNothing);
  });

  testWidgets('YABANCI dosya: diyalog HİÇ açılmıyor, sebebi söyleniyor',
      (tester) async {
    await seedOne();
    await pump(tester);
    picker.text = '{"format":"baska_uygulama"}';

    await tester.tap(find.byKey(const Key('backup-import')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('backup-restore-dialog')), findsNothing);
    expect(find.text('Bu bir Sınav Odak yedeği değil.'), findsOneWidget);
  });

  testWidgets('BOZUK dosya: ayrı mesaj', (tester) async {
    // Her ret sebebine ayrı metin: kullanıcı ne yapacağını bilsin.
    await seedOne();
    await pump(tester);
    picker.text = 'bu bir yedek değil';

    await tester.tap(find.byKey(const Key('backup-import')));
    await tester.pumpAndSettle();

    expect(
      find.text('Bu dosya okunamadı. Yedek dosyası bozuk olabilir.'),
      findsOneWidget,
    );
  });

  testWidgets('ÇOK YENİ yedek: güncelleme isteniyor', (tester) async {
    await seedOne();
    await pump(tester);
    picker.text = '{"format":"sinav_odak_backup","formatVersion":1,'
        '"schemaVersion":99,"tables":{}}';

    await tester.tap(find.byKey(const Key('backup-import')));
    await tester.pumpAndSettle();

    expect(find.textContaining('daha yeni bir sürümünden'), findsOneWidget);
    expect(find.byKey(const Key('backup-restore-dialog')), findsNothing);
  });

  testWidgets('onay diyaloğu NE GELECEĞİNİ söylüyor', (tester) async {
    await seedOne();
    await pump(tester);

    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pumpAndSettle();
    picker.text = share.content;

    await tester.tap(find.byKey(const Key('backup-import')));
    await tester.pumpAndSettle();

    // "1 oturum ve 0 okuma" — kullanıcı körlemesine onaylamıyor.
    //
    // Finder DİYALOĞA daraltılıyor: yedek alma bildirimi de artık aynı
    // dili konuşuyor ("1 oturum, 0 okuma"), ekranda iki eşleşme var.
    final dialog = find.byKey(const Key('backup-restore-dialog'));
    expect(
      find.descendant(of: dialog, matching: find.textContaining('1 oturum')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('Geri alınamaz'),
      ),
      findsOneWidget,
    );
  });
}
