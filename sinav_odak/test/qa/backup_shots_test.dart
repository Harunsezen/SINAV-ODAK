import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/usecases/export_backup.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/theme/app_theme.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/ports/backup_file_gateway.dart';
import 'package:sinav_odak/domain/ports/share_gateway.dart';
import 'package:sinav_odak/presentation/settings/settings_screen.dart';

import '../unit/usecase_helpers.dart';
import 'qa_harness.dart';

/// v1.3/YEDEK — EKRAN GÖRÜNTÜLERİ ve GERÇEK YEDEK DOSYASI.
///
/// Yeşil test "kod çalışıyor" der; **görünüyor mu, dosya gerçekten
/// taşınabilir mi** onu söylemez. Bu dosya ikisini de üretiyor:
/// `qa_backup/` altına ekran görüntüleri ve diskte açılabilir gerçek bir
/// `.json` yedek.
class _Capture implements ShareGateway {
  String? content;
  String? fileName;

  @override
  Future<bool> shareText({
    required String content,
    required String fileName,
    String? subject,
  }) async {
    this.content = content;
    this.fileName = fileName;
    return true;
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

class _Picker implements BackupFileGateway {
  String? text;

  @override
  Future<String?> pickBackupText() async => text;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FontLoadResult fonts;
  late Directory outDir;
  late _Capture share;
  late _Picker picker;

  setUpAll(() async {
    fonts = await loadRealFonts();
    outDir = Directory('qa_backup');
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);
    File('${outDir.path}/README.txt').writeAsStringSync(
      'Sınav Odak v1.3 — yedekleme/geri yükleme kanıtları\n'
      'Üretim: flutter test test/qa/backup_shots_test.dart\n'
      'Font: ${fonts.detail}\n',
    );
  });

  setUp(() {
    db = newDb();
    share = _Capture();
    picker = _Picker();
  });
  tearDown(() async => db.close());

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(qaRepaintKey),
    );
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      try {
        return await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
    });
    File(
      '${outDir.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  /// Ayarlar ekranını DOĞRUDAN kurar.
  ///
  /// `qa_harness.pumpQaSettings` ek override almadığı için burada
  /// kopyalanıyor: yedek satırları sahte paylaşım/dosya kapılarına
  /// ihtiyaç duyuyor. Router üzerinden gidilemiyor — `/settings` debug
  /// derlemede geliştirici sayfasını açıyor (KARAR D4/K3).
  Future<void> openSettings(WidgetTester tester) async {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
        shareGatewayProvider.overrideWithValue(share as ShareGateway),
        backupFileGatewayProvider
            .overrideWithValue(picker as BackupFileGateway),
        appVersionProvider.overrideWithValue('1.3.0+6'),
      ],
    );
    addTearDown(c.dispose);
    await c.read(settingsStreamProvider.future);
    await c.read(activeSessionProvider.future);

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: RepaintBoundary(
          key: qaRepaintKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: const Locale('tr'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToBackup(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.byKey(const Key('backup-export')),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('01 · ayarlarda YEDEK bölümü görünüyor', (tester) async {
    await QaSeed.activeUser(db);
    await openSettings(tester);
    await scrollToBackup(tester);
    await shoot(tester, '01_ayarlar_yedek_bolumu');
    expect(tester.takeException(), isNull);
  });

  testWidgets('02 · GERİ YÜKLE onay diyaloğu', (tester) async {
    await QaSeed.activeUser(db);
    await openSettings(tester);
    await scrollToBackup(tester);

    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pumpAndSettle();
    picker.text = share.content;

    await tester.tap(find.byKey(const Key('backup-import')));
    await tester.pumpAndSettle();
    await shoot(tester, '02_geri_yukle_onay');

    expect(find.byKey(const Key('backup-restore-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('03 · yabancı dosya reddi', (tester) async {
    await QaSeed.activeUser(db);
    await openSettings(tester);
    await scrollToBackup(tester);
    picker.text = '{"format":"baska_uygulama"}';

    await tester.tap(find.byKey(const Key('backup-import')));
    await tester.pumpAndSettle();
    await shoot(tester, '03_yabanci_dosya_reddi');

    expect(find.byKey(const Key('backup-restore-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('04 · GERÇEK yedek dosyası diske yazılıyor', (tester) async {
    // Kanıt: testin ürettiği metin gerçekten bir dosya olarak açılabiliyor
    // ve içinde kullanıcının geçmişi duruyor.
    await QaSeed.activeUser(db);
    final use = ExportBackupUseCase(db, share as ShareGateway);
    final summary = await use(nowMs: t0, appVersion: '1.3.0+6');

    expect(summary, isNotNull);
    final raw = share.content!;
    File('${outDir.path}/${share.fileName}').writeAsStringSync(raw);

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final tables = (map['tables'] as Map).cast<String, dynamic>();
    final rapor = StringBuffer()
      ..writeln('YEDEK DOSYASI — ${share.fileName}')
      ..writeln('boyut: ${raw.length} bayt')
      ..writeln('imza: ${map['format']}')
      ..writeln('biçim sürümü: ${map['formatVersion']}')
      ..writeln('şema sürümü: ${map['schemaVersion']}')
      ..writeln('uygulama: ${map['appVersion']}')
      ..writeln('')
      ..writeln('TABLOLAR:');
    for (final e in tables.entries) {
      rapor.writeln('  ${e.key}: ${(e.value as List).length} satır');
    }
    rapor
      ..writeln('')
      ..writeln(
        'Kişisel sunucuya giden veri: YOK — dosya kullanıcıda kalıyor.',
      );
    File('${outDir.path}/yedek_ozeti.txt').writeAsStringSync(rapor.toString());
    // ignore: avoid_print
    print(rapor);

    expect(map['format'], 'sinav_odak_backup');
    expect(tables.containsKey('daily_stats'), isFalse);
  });
}
