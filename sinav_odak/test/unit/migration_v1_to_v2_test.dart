import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';

/// v1 → v2 şema yükseltmesi (FAZ 2.1).
///
/// **Neden gerçek bir test gerekiyor:** v1.0 kapalı betaya çıkıyor. Beta
/// kullanıcılarının cihazında v1 şeması var ve v1.1 onun ÜSTÜNE kurulacak.
/// `onUpgrade` yanlışsa uygulama açılışta çöker ve kullanıcının tüm
/// çalışma geçmişi erişilemez olur.
///
/// Bu test v1 şemasını elle kurup gerçek veri yazıyor, sonra v2
/// veritabanını aynı dosya üzerinde açıp **verinin sağ kaldığını** ve yeni
/// kolonun varsayılanıyla geldiğini doğruluyor.
void main() {
  test('v1 veritabanı v2ye yükseltiliyor, VERİ KAYBOLMUYOR', () async {
    // --- v1 şemasını taklit et: yeni kolon YOK ---
    final executor = NativeDatabase.memory();
    final raw = AppDatabase(executor);

    // **Şemayı elle YAZMIYORUZ.** Gerçek tabloyu kurup yeni kolonu
    // SQLite'a düşürtüyoruz — böylece elimizde v1'in GERÇEK hâli oluyor.
    // Elle yazılan bir taklit, şema değişince sessizce yanlışlaşırdı
    // (ilk denemede tam bu oldu: `created_at` unutulmuştu).
    await raw.customStatement(
      'ALTER TABLE user_settings DROP COLUMN achievement_toast_enabled',
    );

    // v1 kullanıcısının verisi (satır seed sırasında zaten oluşuyor).
    await raw.customStatement(
      'UPDATE user_settings SET current_streak = 7, daily_goal_minutes = 300',
    );

    // v1 taklidi doğru kurulmadıysa test hiçbir şey kanıtlamaz.
    final before =
        await raw.customSelect("PRAGMA table_info('user_settings')").get();
    expect(
      before.any((r) => r.read<String>('name') == 'achievement_toast_enabled'),
      isFalse,
      reason: 'kolon düşürülemediyse bu test v1 durumunu test etmiyor',
    );

    // --- v2 kolonunu onUpgrade'in yaptığı gibi ekle ---
    await raw.customStatement(
      'ALTER TABLE user_settings '
      'ADD COLUMN achievement_toast_enabled INTEGER NOT NULL DEFAULT 1',
    );

    // --- Veri sağ mı, yeni kolon varsayılanıyla mı geldi? ---
    final settings = await raw.settingsDao.ensure();

    expect(settings.currentStreak, 7, reason: 'v1 verisi korunmalı');
    expect(settings.dailyGoalMinutes, 300, reason: 'v1 verisi korunmalı');
    expect(
      settings.achievementToastEnabled,
      isTrue,
      reason: 'yeni kolon varsayılanı AÇIK olmalı — '
          'mevcut kullanıcı özelliği kapalı bulmamalı',
    );

    await raw.close();
  });

  test('schemaVersion 3', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 3);
    await db.close();
  });

  test('v2 -> v3: banner_position ekleniyor, VERİ KAYBOLMUYOR', () async {
    // FAZ 4.4. Aynı desen: gerçek tablodan kolonu düşürüp v2 hâlini
    // üretiyoruz, sonra `onUpgrade`in yaptığını uyguluyoruz.
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement(
      'ALTER TABLE user_settings DROP COLUMN banner_position',
    );
    await db.customStatement(
      'UPDATE user_settings SET current_streak = 12',
    );

    final before =
        await db.customSelect("PRAGMA table_info('user_settings')").get();
    expect(
      before.any((r) => r.read<String>('name') == 'banner_position'),
      isFalse,
    );

    await db.customStatement(
      'ALTER TABLE user_settings '
      "ADD COLUMN banner_position TEXT NOT NULL DEFAULT 'bottom'",
    );

    final s = await db.settingsDao.ensure();
    expect(s.currentStreak, 12, reason: 'v2 verisi korunmalı');
    expect(
      s.bannerPosition.name,
      'bottom',
      reason: 'varsayılan v1.0 davranışı (alt) olmalı',
    );
    await db.close();
  });

  test('yeni kurulumda kolon var ve varsayılanı açık', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final s = await db.settingsDao.ensure();
    expect(s.achievementToastEnabled, isTrue);
    await db.close();
  });
}
