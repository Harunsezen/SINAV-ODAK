import 'package:drift/drift.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/time.dart';
import '../../domain/entities/enums.dart';
import 'curriculum_data.dart';
import 'database.dart';

/// İlk kurulumda yüklenen varsayılan katalog.
///
/// ID'ler sabit ve okunabilir ('sub_yks_mat'): böylece seed verisi
/// yeniden çalıştırılsa bile kopya oluşmaz ve migration'larda referans
/// verilebilir.
abstract final class SeedData {
  static Future<void> populate(AppDatabase db) async {
    final ts = nowMs();
    // insertOrIgnore ZORUNLU: bu metot beforeOpen kurtarma yolundan yeniden
    // çağrılabiliyor. Varsayılan insert modu PK çakışmasında exception
    // fırlatır ve veritabanı bir daha HİÇ açılmaz hale gelir.
    const mode = InsertMode.insertOrIgnore;
    await db.batch((b) {
      b.insertAll(db.activityTypes, _activityTypes(), mode: mode);
      b.insertAll(db.subjects, _subjects(ts), mode: mode);
      b.insertAll(db.topics, _topics(ts), mode: mode);
    });

    await _syncSubjectOrder(db);
    await _renameLegacyTopics(db);
    await _seedCurriculum(db, ts);

    await db.into(db.userSettings).insert(
          UserSettingsCompanion.insert(createdAt: ts),
          mode: InsertMode.insertOrIgnore,
        );
  }

  // --- Çalışma türleri (11 adet, spec bölüm 8) ---
  static List<ActivityTypesCompanion> _activityTypes() {
    const rows = <(String, String, String)>[
      ('act_konu', 'Konu Anlatımı', 'menu_book'),
      ('act_tekrar', 'Tekrar', 'replay'),
      ('act_soru', 'Soru Çözümü', 'edit_note'),
      ('act_deneme', 'Deneme', 'assignment'),
      ('act_brans', 'Branş Denemesi', 'assignment_turned_in'),
      ('act_genel', 'Genel Deneme', 'fact_check'),
      ('act_not', 'Not Çıkarma', 'draw'),
      ('act_ezber', 'Ezber', 'psychology'),
      ('act_video', 'Video İzleme', 'play_circle'),
      ('act_analiz', 'Analiz / Yanlış Defteri', 'search'),
      ('act_serbest', 'Serbest Çalışma', 'bolt'),
    ];
    var i = 0;
    return rows
        .map(
          (r) => ActivityTypesCompanion.insert(
            id: r.$1,
            name: r.$2,
            iconKey: Value(r.$3),
            isDefault: const Value(true),
            sortOrder: Value(i++),
          ),
        )
        .toList();
  }

  // --- Dersler ---
  //
  // `(ad, görüntü sırası)`. **Liste sırası = KİMLİK sırası:** `sub_yks_7`
  // bugün Coğrafya; araya ders eklemek o kimliği başka bir derse çevirir
  // ve geçmiş oturumlar yanlış derse bağlanır. Bu yüzden yeni ders yalnızca
  // SONA ekleniyor; ekranda görünmesi gereken yer ikinci alanla veriliyor.
  static const _subjectsByExam = <ExamType, List<(String, int)>>{
    ExamType.yks: [
      ('Türkçe', 0),
      ('Matematik', 2),
      ('Geometri', 3),
      ('Fizik', 4),
      ('Kimya', 5),
      ('Biyoloji', 6),
      ('Tarih', 7),
      ('Coğrafya', 8),
      ('Felsefe', 9),
      ('Din Kültürü', 10),
      ('İngilizce', 11),
      ('TYT Genel', 12),
      ('AYT Genel', 13),
      ('Deneme', 14),
      ('Diğer', 15),
      // v1.2'de eklendi. Kimlik `sub_yks_15`, görünen yer Türkçe'nin altı.
      ('Edebiyat', 1),
    ],
    ExamType.lgs: [
      ('Türkçe', 0),
      ('Matematik', 1),
      ('Fen Bilimleri', 2),
      ('T.C. İnkılap Tarihi', 3),
      ('Din Kültürü', 4),
      ('İngilizce', 5),
      ('Deneme', 6),
      ('Diğer', 7),
    ],
    ExamType.kpss: [
      ('Türkçe', 0),
      ('Matematik', 1),
      ('Tarih', 2),
      ('Coğrafya', 3),
      ('Vatandaşlık', 4),
      ('Güncel Bilgiler', 5),
      ('Eğitim Bilimleri', 6),
      ('Deneme', 7),
      ('Diğer', 8),
    ],
    ExamType.ales: [('Sayısal', 0), ('Sözel', 1), ('Deneme', 2), ('Diğer', 3)],
    ExamType.dgs: [('Sayısal', 0), ('Sözel', 1), ('Deneme', 2), ('Diğer', 3)],
    ExamType.other: [('Genel Çalışma', 0), ('Deneme', 1), ('Diğer', 2)],
  };

  /// Sabit ID üretimi: 'sub_yks_0', 'sub_lgs_3' ...
  static String subjectId(ExamType exam, int index) =>
      'sub_${exam.name}_$index';

  static List<SubjectsCompanion> _subjects(int ts) {
    final out = <SubjectsCompanion>[];
    for (final entry in _subjectsByExam.entries) {
      const palette = AppColors.subjectPalette;
      for (var i = 0; i < entry.value.length; i++) {
        out.add(
          SubjectsCompanion.insert(
            id: subjectId(entry.key, i),
            name: entry.value[i].$1,
            colorHex: palette[i % palette.length],
            examType: entry.key,
            sortOrder: Value(entry.value[i].$2),
            isDefault: const Value(true),
            createdAt: ts,
          ),
        );
      }
    }
    return out;
  }

  // --- Konular (yalnızca en çok kullanılan YKS dersleri için ön yükleme;
  //     kullanıcı her derse kendi konusunu ekleyebilir) ---
  static const _topicsBySubjectId = <String, List<String>>{
    'sub_yks_0': [
      // Türkçe
      'Sözcükte Anlam', 'Cümlede Anlam', 'Paragraf', 'Ses Bilgisi',
      'Yazım Kuralları', 'Noktalama', 'Sözcük Türleri', 'Cümlenin Ögeleri',
      'Fiilimsi', 'Cümle Türleri', 'Anlatım Bozukluğu',
    ],
    'sub_yks_1': [
      // Matematik
      'Temel Kavramlar', 'Sayı Basamakları', 'Bölme–Bölünebilme', 'EBOB–EKOK',
      'Rasyonel Sayılar', 'Basit Eşitsizlikler', 'Mutlak Değer', 'Üslü Sayılar',
      'Köklü Sayılar', 'Çarpanlara Ayırma', 'Oran–Orantı', 'Problemler',
      'Kümeler', 'Fonksiyonlar', 'Polinomlar', 'İkinci Dereceden Denklemler',
      'Permütasyon–Kombinasyon', 'Olasılık', 'Trigonometri', 'Logaritma',
      'Diziler', 'Limit', 'Türev', 'İntegral',
    ],
    'sub_yks_2': [
      // Geometri
      'Doğruda Açılar', 'Üçgende Açılar', 'Dik Üçgen', 'İkizkenar–Eşkenar',
      'Açıortay–Kenarortay', 'Üçgende Alan', 'Benzerlik', 'Çokgenler',
      'Dörtgenler', 'Çember ve Daire', 'Katı Cisimler', 'Analitik Geometri',
    ],
    'sub_yks_3': [
      // Fizik
      'Fizik Bilimine Giriş', 'Madde ve Özellikleri', 'Hareket ve Kuvvet',
      'Enerji', 'Isı ve Sıcaklık', 'Elektrostatik', 'Elektrik Akımı',
      'Manyetizma', 'Basınç', 'Kaldırma Kuvveti', 'Dalgalar', 'Optik',
      'Modern Fizik',
    ],
    'sub_yks_4': [
      // Kimya
      'Kimya Bilimi', 'Atom ve Periyodik Sistem',
      'Kimyasal Türler Arası Etkileşim',
      'Maddenin Halleri', 'Kimyanın Temel Kanunları', 'Mol Kavramı',
      'Karışımlar', 'Asit–Baz–Tuz', 'Kimya Her Yerde', 'Modern Atom Teorisi',
      'Gazlar', 'Çözeltiler', 'Kimyasal Tepkimelerde Enerji', 'Kimyasal Denge',
      'Organik Kimya',
    ],
    'sub_yks_5': [
      // Biyoloji
      'Canlıların Ortak Özellikleri', 'Hücre', 'Madde Geçişleri',
      'Canlıların Sınıflandırılması', 'Hücre Bölünmeleri', 'Kalıtım',
      'Ekosistem Ekolojisi', 'Sinir Sistemi', 'Endokrin Sistem',
      'Duyu Organları', 'Destek ve Hareket', 'Sindirim', 'Dolaşım',
      'Solunum', 'Boşaltım', 'Üreme ve Gelişme', 'Bitki Biyolojisi',
    ],
    'sub_yks_6': [
      // Tarih
      'İlk Uygarlıklar', 'İlk Türk Devletleri', 'İslam Tarihi',
      'Türk–İslam Devletleri', 'Anadolu Selçuklu', 'Osmanlı Kuruluş',
      'Osmanlı Yükselme', 'Osmanlı Duraklama', 'Osmanlı Gerileme',
      'XX. Yüzyıl Başları', 'Kurtuluş Savaşı', 'İnkılaplar',
      'Atatürk İlkeleri', 'II. Dünya Savaşı', 'Soğuk Savaş',
    ],
    'sub_yks_7': [
      // Coğrafya
      'Doğa ve İnsan', 'Harita Bilgisi', 'Dünyanın Şekli ve Hareketleri',
      'İklim Bilgisi', 'İç Kuvvetler', 'Dış Kuvvetler', 'Toprak ve Bitki',
      'Nüfus', 'Göç', 'Yerleşme', 'Ekonomik Faaliyetler',
      'Türkiye Fiziki Coğrafyası', 'Türkiye Beşeri Coğrafyası',
      'Bölgeler', 'Çevre ve Toplum',
    ],
    'sub_yks_8': [
      // Felsefe
      'Felsefeye Giriş', 'Bilgi Felsefesi', 'Varlık Felsefesi',
      'Ahlak Felsefesi', 'Sanat Felsefesi', 'Din Felsefesi',
      'Siyaset Felsefesi', 'Bilim Felsefesi', 'Psikoloji', 'Sosyoloji',
      'Mantık',
    ],
    'sub_lgs_0': [
      // LGS Türkçe
      'Sözcükte Anlam', 'Cümlede Anlam', 'Paragraf', 'Fiilimsiler',
      'Cümlenin Ögeleri', 'Fiilde Çatı', 'Cümle Çeşitleri',
      'Anlatım Bozuklukları', 'Yazım Kuralları', 'Noktalama İşaretleri',
    ],
    'sub_lgs_1': [
      // LGS Matematik
      'Çarpanlar ve Katlar', 'Üslü İfadeler', 'Kareköklü İfadeler',
      'Veri Analizi', 'Olasılık', 'Cebirsel İfadeler', 'Denklemler',
      'Eşitsizlikler', 'Üçgenler', 'Eşlik ve Benzerlik', 'Dönüşüm Geometrisi',
      'Geometrik Cisimler',
    ],
    'sub_lgs_2': [
      // LGS Fen
      'Mevsimler ve İklim', 'DNA ve Genetik Kod', 'Basınç', 'Madde ve Endüstri',
      'Basit Makineler', 'Enerji Dönüşümleri', 'Elektrik Yükleri',
    ],
  };

  static List<TopicsCompanion> _topics(int ts) {
    final out = <TopicsCompanion>[];
    for (final entry in _topicsBySubjectId.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        out.add(
          TopicsCompanion.insert(
            id: 'top_${entry.key}_$i',
            subjectId: entry.key,
            name: entry.value[i],
            sortOrder: Value(i),
            createdAt: ts,
          ),
        );
      }
    }
    return out;
  }
  // =====================================================================
  // MÜFREDAT BİRLEŞTİRME (v1.2)
  // =====================================================================

  /// Varsayılan derslerin görüntü sırasını kanonik değere çeker.
  ///
  /// `sortOrder` yalnızca GÖRÜNTÜ alanı; kimlik değil. Sona eklenen bir
  /// ders (Edebiyat) listede "Diğer"in altında kalmasın diye burada
  /// düzeltiliyor. `insertOrIgnore` var olan satırı hiç yazmadığı için
  /// yükseltmede sıranın düzelmesinin tek yolu bu.
  ///
  /// Yalnızca `isDefault` satırlara dokunuyor: kullanıcının eklediği ders
  /// nerede duruyorsa orada kalıyor.
  static Future<void> _syncSubjectOrder(AppDatabase db) async {
    await db.batch((b) {
      for (final entry in _subjectsByExam.entries) {
        for (var i = 0; i < entry.value.length; i++) {
          b.update(
            db.subjects,
            SubjectsCompanion(sortOrder: Value(entry.value[i].$2)),
            where: (t) =>
                t.id.equals(subjectId(entry.key, i)) & t.isDefault.equals(true),
          );
        }
      }
    });
  }

  /// v1.1 konu adlarını müfredattaki kanonik adlara çeker.
  ///
  /// **Neden yeniden adlandırma, yeniden ekleme değil:** eski satırın
  /// kimliği geçmiş oturumlara ve yanlış defterine bağlı. Yeni adla ikinci
  /// bir satır eklemek aynı konuyu listede iki kez gösterirdi ve
  /// istatistikler ikiye bölünürdü. `UPDATE` kimliği koruyor, bağlı hiçbir
  /// kayıt kopmuyor.
  ///
  /// Hedef ad zaten varsa yeniden adlandırma ATLANIYOR — aksi halde aynı
  /// derste iki özdeş ad oluşurdu.
  static Future<void> _renameLegacyTopics(AppDatabase db) async {
    for (final entry in _legacyRenames.entries) {
      final sid = entry.key;
      final rows = await (db.select(db.topics)
            ..where((t) => t.subjectId.equals(sid)))
          .get();
      final names = {for (final r in rows) r.name};

      for (final rename in entry.value.entries) {
        if (names.contains(rename.value)) continue;
        // Ada göre toplu UPDATE yerine SATIR KİMLİĞİYLE: aynı ad bir derste
        // iki kez geçerse toplu güncelleme ikisini birden kanonik ada
        // çevirir ve tam kaçınmak istediğimiz ikizi üretir.
        final hedef = rows.where((r) => r.name == rename.key).toList();
        if (hedef.isEmpty) continue;
        await (db.update(db.topics)..where((t) => t.id.equals(hedef.first.id)))
            .write(TopicsCompanion(name: Value(rename.value)));
        if (hedef.length == 1) names.remove(rename.key);
        names.add(rename.value);
      }
    }
  }

  /// Müfredatı katalogla birleştirir: eksikleri ekler, var olanların boş
  /// alanlarını doldurur, HİÇBİR şeyi silmez.
  ///
  /// Eşleme **(ders, konu adı)** üzerinden. Sıra numarası üzerinden değil:
  /// müfredata ortadan bir konu eklendiğinde indeks tabanlı kimlikler
  /// kayardı ve yükseltmede her konu ikiye çıkardı.
  ///
  /// Var olan satırda dolu olan alan **ezilmiyor**: kullanıcı bir konuyu
  /// yeniden adlandırmış veya başka bir sınıfa taşımış olabilir.
  static Future<void> _seedCurriculum(AppDatabase db, int ts) async {
    final all = await db.select(db.topics).get();

    String key(String sid, String name) => '$sid $name';
    final knownId = <String, String>{
      for (final t in all) key(t.subjectId, t.name): t.id,
    };
    final knownRow = <String, Topic>{
      for (final t in all) key(t.subjectId, t.name): t,
    };
    final usedIds = {for (final t in all) t.id};
    final nextOrder = <String, int>{};
    for (final t in all) {
      final cur = nextOrder[t.subjectId];
      if (cur == null || t.sortOrder > cur) {
        nextOrder[t.subjectId] = t.sortOrder;
      }
    }

    final inserts = <TopicsCompanion>[];
    final patches = <String, TopicsCompanion>{};

    String resolve(
      String sid,
      String name, {
      int? grade,
      String? tag,
      String? parent,
    }) {
      final k = key(sid, name);
      final existingId = knownId[k];
      if (existingId != null) {
        final row = knownRow[k];
        if (row != null) {
          final needsGrade = row.grade == null && grade != null;
          final needsTag = row.examTag == null && tag != null;
          final needsParent = row.parentId == null && parent != null;
          if (needsGrade || needsTag || needsParent) {
            patches[existingId] = TopicsCompanion(
              grade: needsGrade ? Value(grade) : const Value.absent(),
              examTag: needsTag ? Value(tag) : const Value.absent(),
              parentId: needsParent ? Value(parent) : const Value.absent(),
            );
          }
        }
        return existingId;
      }

      final order = (nextOrder[sid] ?? -1) + 1;
      nextOrder[sid] = order;
      final id = _freeTopicId(sid, name, usedIds);
      inserts.add(
        TopicsCompanion.insert(
          id: id,
          subjectId: sid,
          name: name,
          sortOrder: Value(order),
          grade: Value(grade),
          examTag: Value(tag),
          parentId: Value(parent),
          createdAt: ts,
        ),
      );
      knownId[k] = id;
      return id;
    }

    for (final entry in _subjectsByExam.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final sid = subjectId(entry.key, i);
        final plan = CurriculumData.forSubject(entry.key, entry.value[i].$1);
        for (final topic in plan) {
          final parentRowId = resolve(
            sid,
            topic.name,
            grade: topic.grade,
            tag: topic.tag,
          );
          for (final child in topic.children ?? const <String>[]) {
            resolve(
              sid,
              child,
              grade: topic.grade,
              tag: topic.tag,
              parent: parentRowId,
            );
          }
        }
      }
    }

    if (inserts.isEmpty && patches.isEmpty) return;
    await db.batch((b) {
      b.insertAll(db.topics, inserts, mode: InsertMode.insertOrIgnore);
      for (final p in patches.entries) {
        b.update(db.topics, p.value, where: (t) => t.id.equals(p.key));
      }
    });
  }

  /// Konu kimliği: `top_<dersId>_<ad-slug>`.
  ///
  /// **Slug, indeks değil.** İndeks tabanlı kimlik müfredat ortasına konu
  /// eklendiğinde kayar; ada bağlı kimlik yerinde kalır. Çakışma olursa
  /// (kısaltma iki adı aynı slug'a indirebilir) sonuna sayaç ekleniyor.
  static String _freeTopicId(String sid, String name, Set<String> used) {
    final base = 'top_${sid}_${_slug(name)}';
    var id = base;
    var n = 2;
    while (used.contains(id)) {
      id = '${base}_$n';
      n++;
    }
    used.add(id);
    return id;
  }

  /// Türkçe harfleri ASCII'ye indirir, geri kalanı ayraç yapar.
  ///
  /// `toLowerCase()` tek başına yetmiyor: 'İ' birleşik noktalı i üretiyor
  /// ve slug'ın ortasına ayraç sokuyor. Harfler önceden sabitleniyor.
  static String _slug(String name) {
    const tr = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'â': 'a',
      'î': 'i',
      'û': 'u',
    };
    final lower = name.replaceAll('İ', 'i').replaceAll('I', 'i').toLowerCase();
    final out = StringBuffer();
    var pendingSep = false;
    for (final ch in lower.split('')) {
      final c = tr[ch] ?? ch;
      if (RegExp(r'^[a-z0-9]$').hasMatch(c)) {
        if (pendingSep && out.isNotEmpty) out.write('_');
        pendingSep = false;
        out.write(c);
      } else {
        pendingSep = true;
      }
    }
    final s = out.toString();
    return s.length <= 48 ? s : s.substring(0, 48);
  }

  /// v1.1 konu adı iken müfredattaki kanonik ad.
  ///
  /// Bu tablo olmasaydı 'Köklü Sayılar' ile 'Kareköklü İfadeler' aynı
  /// derste yan yana dururdu: aynı konu, iki satır, bölünmüş istatistik.
  static const _legacyRenames = <String, Map<String, String>>{
    'sub_yks_0': {
      'Noktalama': 'Noktalama İşaretleri',
      'Fiilimsi': 'Fiilimsiler',
      'Anlatım Bozukluğu': 'Anlatım Bozuklukları',
    },
    'sub_yks_1': {
      'Bölme–Bölünebilme': 'Bölme ve Bölünebilme',
      'EBOB–EKOK': 'Çarpanlar ve Katlar',
      'Basit Eşitsizlikler': 'Eşitsizlikler',
      'Üslü Sayılar': 'Üslü İfadeler',
      'Köklü Sayılar': 'Kareköklü İfadeler',
      'Oran–Orantı': 'Oran ve Orantı',
      'Permütasyon–Kombinasyon': 'Permütasyon ve Kombinasyon',
      'Limit': 'Limit ve Süreklilik',
    },
    'sub_yks_2': {
      'İkizkenar–Eşkenar': 'İkizkenar ve Eşkenar Üçgen',
      'Açıortay–Kenarortay': 'Açıortay ve Kenarortay',
      'Benzerlik': 'Üçgende Eşlik ve Benzerlik',
    },
    'sub_yks_3': {'Basınç': 'Basınç ve Kaldırma Kuvveti'},
    'sub_yks_4': {
      'Maddenin Halleri': 'Maddenin Hâlleri',
      'Asit–Baz–Tuz': 'Asitler Bazlar ve Tuzlar',
      'Kimya Her Yerde': 'Doğa ve Kimya',
      'Çözeltiler': 'Sıvı Çözeltiler',
      'Kimyasal Denge': 'Tepkime Hızı ve Denge',
    },
    'sub_yks_5': {
      'Destek ve Hareket': 'Destek ve Hareket Sistemi',
      'Sindirim': 'Sindirim Sistemi',
      'Dolaşım': 'Dolaşım ve Bağışıklık',
      'Boşaltım': 'Boşaltım Sistemi',
      'Üreme ve Gelişme': 'Üreme Sistemi',
    },
    'sub_yks_6': {
      'İlk Uygarlıklar': 'İnsanlığın İlk Dönemleri',
      'İlk Türk Devletleri': 'İlk ve Orta Çağlarda Türk Dünyası',
      'İslam Tarihi': 'İslam Medeniyetinin Doğuşu',
      'Türk–İslam Devletleri': 'Türklerin İslamiyet\'i Kabulü',
      'Anadolu Selçuklu': 'Anadolu Selçuklu Devleti',
      'Osmanlı Kuruluş': 'Beylikten Devlete Osmanlı',
      'Osmanlı Yükselme': 'Beylikten Cihan Devletine',
      'Osmanlı Duraklama': 'Değişen Dünya Dengeleri',
      'Osmanlı Gerileme': 'Uluslararası İlişkilerde Denge Stratejisi',
      'XX. Yüzyıl Başları': 'XX. Yüzyıl Başlarında Osmanlı ve Dünya',
      'Kurtuluş Savaşı': 'Millî Mücadele',
      'İnkılaplar': 'Atatürkçülük ve Türk İnkılabı',
      'II. Dünya Savaşı': 'II. Dünya Savaşı ve Türkiye',
      'Soğuk Savaş': 'Soğuk Savaş Dönemi',
    },
    'sub_yks_7': {
      'Dünyanın Şekli ve Hareketleri': 'Dünya\'nın Şekli ve Hareketleri',
      'Toprak ve Bitki': 'Toprak ve Bitki Örtüsü',
      'Türkiye Fiziki Coğrafyası': 'Türkiye\'nin Fiziki Coğrafyası',
      'Türkiye Beşeri Coğrafyası': 'Türkiye\'de Nüfus ve Yerleşme',
      'Bölgeler': 'Bölge ve Ülke Sınıflandırması',
      'Çevre ve Toplum': 'Çevre Sorunları ve Yönetimi',
    },
    'sub_yks_8': {'Felsefeye Giriş': 'Felsefeyi Tanıma'},
    'sub_lgs_0': {'Cümle Çeşitleri': 'Cümle Türleri'},
    'sub_lgs_2': {'Elektrik Yükleri': 'Elektrik Yükleri ve Elektrik Enerjisi'},
  };
}
