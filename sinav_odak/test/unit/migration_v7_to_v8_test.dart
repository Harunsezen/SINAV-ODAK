import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';

/// v7 → v8 şema yükseltmesi (v1.5 — reklam gösterimi rızadan ayrıldı).
///
/// **Neden GERÇEK göç koşuluyor:** bu depodaki eski göç testi şemayı elle
/// taklit edip `ALTER TABLE`'ı kendisi yazıyor — yani testin doğruladığı
/// şey `onUpgrade`'in kendisi değil, testin kopyası. Göçte bir yazım hatası
/// olsa o test yine yeşil kalırdı.
///
/// Burada `PRAGMA user_version` 7'ye düşürülüp veritabanı yeniden açılıyor;
/// Drift kendi `onUpgrade`'ini çalıştırıyor. Kırılırsa burada kırılır.
///
/// Kırmızı çizgi: mağazada 1.4.0 kullanan gerçek kişiler var. Göç çökerse
/// uygulama AÇILIŞTA ölür ve tüm çalışma geçmişleri erişilemez olur.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('sinavodak_mig'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// **DOSYA tabanlı** veritabanı şart ve yol GERÇEKTEN interpolasyonlu
  /// olmalı: ilk yazımda `\$` kaçırılmıştı, dört test de `\${tmp.path}`
  /// adlı TEK bir dosyayı paylaştı ve bir testin verisi diğerine sızdı.
  /// Aynı açık executor'ı iki
  /// `AppDatabase`e vermek göçü YENİDEN ÇALIŞTIRMIYOR (ilk denemede tam
  /// bu oldu, test `ads_enabled` null diye çöktü). Dosyayı kapatıp yeniden
  /// açmak gerçek cihazdaki güncelleme akışının aynısı.
  File dbFile() => File('${tmp.path}/app.sqlite');

  /// v8 şemasını v7 hâline döndürür.
  Future<void> makeItLookLikeV7(AppDatabase db) async {
    await db
        .customStatement('ALTER TABLE user_settings DROP COLUMN ads_enabled');
    await db.customStatement('PRAGMA user_version = 7');
  }

  test('REKLAMI KAPALI olan kullanıcı yükseltmeden sonra da KAPALI kalıyor',
      () async {
    final v7 = AppDatabase(NativeDatabase(dbFile()));
    await v7.settingsDao.ensure();
    // v1.4 davranışı: rıza vermeyen kullanıcı hiç reklam görmüyordu.
    await v7.settingsDao.patchSettings(
      const UserSettingsCompanion(
        personalizedAdsConsent: Value(false),
        currentStreak: Value(11),
      ),
    );
    await makeItLookLikeV7(v7);

    // Dosya yeniden açılıyor: Drift onUpgrade'i ÇALIŞTIRIR.
    final v8 = AppDatabase(NativeDatabase(dbFile()));
    final s = await v8.settingsDao.ensure();

    expect(
      s.adsEnabled,
      isFalse,
      reason: 'v1.4te "reklam görmem" diye seçen kullanıcıya verilen söz '
          'güncellemeyle bozulmamalı',
    );
    expect(s.currentStreak, 11, reason: 'veri kaybolmamalı');
    await v8.close();
  });

  test('RIZA VERMİŞ kullanıcıda reklam AÇIK geliyor', () async {
    final v7 = AppDatabase(NativeDatabase(dbFile()));
    await v7.settingsDao.ensure();
    await v7.settingsDao.patchSettings(
      const UserSettingsCompanion(personalizedAdsConsent: Value(true)),
    );
    await makeItLookLikeV7(v7);

    final v8 = AppDatabase(NativeDatabase(dbFile()));
    final s = await v8.settingsDao.ensure();

    expect(s.adsEnabled, isTrue);
    expect(s.personalizedAdsConsent, isTrue, reason: 'rıza korunmalı');
    await v8.close();
  });

  test('YENİ kurulumda reklam varsayılanı AÇIK', () async {
    // Göç yolundan değil, `onCreate`ten gelen cihaz. Grandfathering
    // satırının yeni kullanıcıyı etkilememesi şart.
    final db = AppDatabase(NativeDatabase(dbFile()));
    final s = await db.settingsDao.ensure();

    expect(s.adsEnabled, isTrue);
    expect(
      s.personalizedAdsConsent,
      isFalse,
      reason: 'kişiselleştirme rızası varsayılan KAPALI kalmalı (KVKK)',
    );
    await db.close();
  });

  test('göç sonrası şema sürümü 8', () async {
    final v7 = AppDatabase(NativeDatabase(dbFile()));
    await v7.settingsDao.ensure();
    await makeItLookLikeV7(v7);

    final v8 = AppDatabase(NativeDatabase(dbFile()));
    await v8.settingsDao.ensure();
    final row = await v8.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, 8);
    await v8.close();
  });
}
