import 'package:drift/drift.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/time.dart';
import '../../domain/entities/enums.dart';
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
  static const _subjectsByExam = <ExamType, List<String>>{
    ExamType.yks: [
      'Türkçe', 'Matematik', 'Geometri', 'Fizik', 'Kimya', 'Biyoloji',
      'Tarih', 'Coğrafya', 'Felsefe', 'Din Kültürü', 'İngilizce',
      'TYT Genel', 'AYT Genel', 'Deneme', 'Diğer',
    ],
    ExamType.lgs: [
      'Türkçe', 'Matematik', 'Fen Bilimleri', 'T.C. İnkılap Tarihi',
      'Din Kültürü', 'İngilizce', 'Deneme', 'Diğer',
    ],
    ExamType.kpss: [
      'Türkçe', 'Matematik', 'Tarih', 'Coğrafya', 'Vatandaşlık',
      'Güncel Bilgiler', 'Eğitim Bilimleri', 'Deneme', 'Diğer',
    ],
    ExamType.ales: ['Sayısal', 'Sözel', 'Deneme', 'Diğer'],
    ExamType.dgs: ['Sayısal', 'Sözel', 'Deneme', 'Diğer'],
    ExamType.other: ['Genel Çalışma', 'Deneme', 'Diğer'],
  };

  /// Sabit ID üretimi: 'sub_yks_0', 'sub_lgs_3' ...
  static String subjectId(ExamType exam, int index) =>
      'sub_${exam.name}_$index';

  static List<SubjectsCompanion> _subjects(int ts) {
    final out = <SubjectsCompanion>[];
    for (final entry in _subjectsByExam.entries) {
      final palette = AppColors.subjectPalette;
      for (var i = 0; i < entry.value.length; i++) {
        out.add(
          SubjectsCompanion.insert(
            id: subjectId(entry.key, i),
            name: entry.value[i],
            colorHex: palette[i % palette.length],
            examType: entry.key,
            sortOrder: Value(i),
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
    'sub_yks_0': [ // Türkçe
      'Sözcükte Anlam', 'Cümlede Anlam', 'Paragraf', 'Ses Bilgisi',
      'Yazım Kuralları', 'Noktalama', 'Sözcük Türleri', 'Cümlenin Ögeleri',
      'Fiilimsi', 'Cümle Türleri', 'Anlatım Bozukluğu',
    ],
    'sub_yks_1': [ // Matematik
      'Temel Kavramlar', 'Sayı Basamakları', 'Bölme–Bölünebilme', 'EBOB–EKOK',
      'Rasyonel Sayılar', 'Basit Eşitsizlikler', 'Mutlak Değer', 'Üslü Sayılar',
      'Köklü Sayılar', 'Çarpanlara Ayırma', 'Oran–Orantı', 'Problemler',
      'Kümeler', 'Fonksiyonlar', 'Polinomlar', 'İkinci Dereceden Denklemler',
      'Permütasyon–Kombinasyon', 'Olasılık', 'Trigonometri', 'Logaritma',
      'Diziler', 'Limit', 'Türev', 'İntegral',
    ],
    'sub_yks_2': [ // Geometri
      'Doğruda Açılar', 'Üçgende Açılar', 'Dik Üçgen', 'İkizkenar–Eşkenar',
      'Açıortay–Kenarortay', 'Üçgende Alan', 'Benzerlik', 'Çokgenler',
      'Dörtgenler', 'Çember ve Daire', 'Katı Cisimler', 'Analitik Geometri',
    ],
    'sub_yks_3': [ // Fizik
      'Fizik Bilimine Giriş', 'Madde ve Özellikleri', 'Hareket ve Kuvvet',
      'Enerji', 'Isı ve Sıcaklık', 'Elektrostatik', 'Elektrik Akımı',
      'Manyetizma', 'Basınç', 'Kaldırma Kuvveti', 'Dalgalar', 'Optik',
      'Modern Fizik',
    ],
    'sub_yks_4': [ // Kimya
      'Kimya Bilimi', 'Atom ve Periyodik Sistem', 'Kimyasal Türler Arası Etkileşim',
      'Maddenin Halleri', 'Kimyanın Temel Kanunları', 'Mol Kavramı',
      'Karışımlar', 'Asit–Baz–Tuz', 'Kimya Her Yerde', 'Modern Atom Teorisi',
      'Gazlar', 'Çözeltiler', 'Kimyasal Tepkimelerde Enerji', 'Kimyasal Denge',
      'Organik Kimya',
    ],
    'sub_yks_5': [ // Biyoloji
      'Canlıların Ortak Özellikleri', 'Hücre', 'Madde Geçişleri',
      'Canlıların Sınıflandırılması', 'Hücre Bölünmeleri', 'Kalıtım',
      'Ekosistem Ekolojisi', 'Sinir Sistemi', 'Endokrin Sistem',
      'Duyu Organları', 'Destek ve Hareket', 'Sindirim', 'Dolaşım',
      'Solunum', 'Boşaltım', 'Üreme ve Gelişme', 'Bitki Biyolojisi',
    ],
    'sub_yks_6': [ // Tarih
      'İlk Uygarlıklar', 'İlk Türk Devletleri', 'İslam Tarihi',
      'Türk–İslam Devletleri', 'Anadolu Selçuklu', 'Osmanlı Kuruluş',
      'Osmanlı Yükselme', 'Osmanlı Duraklama', 'Osmanlı Gerileme',
      'XX. Yüzyıl Başları', 'Kurtuluş Savaşı', 'İnkılaplar',
      'Atatürk İlkeleri', 'II. Dünya Savaşı', 'Soğuk Savaş',
    ],
    'sub_yks_7': [ // Coğrafya
      'Doğa ve İnsan', 'Harita Bilgisi', 'Dünyanın Şekli ve Hareketleri',
      'İklim Bilgisi', 'İç Kuvvetler', 'Dış Kuvvetler', 'Toprak ve Bitki',
      'Nüfus', 'Göç', 'Yerleşme', 'Ekonomik Faaliyetler',
      'Türkiye Fiziki Coğrafyası', 'Türkiye Beşeri Coğrafyası',
      'Bölgeler', 'Çevre ve Toplum',
    ],
    'sub_yks_8': [ // Felsefe
      'Felsefeye Giriş', 'Bilgi Felsefesi', 'Varlık Felsefesi',
      'Ahlak Felsefesi', 'Sanat Felsefesi', 'Din Felsefesi',
      'Siyaset Felsefesi', 'Bilim Felsefesi', 'Psikoloji', 'Sosyoloji',
      'Mantık',
    ],
    'sub_lgs_0': [ // LGS Türkçe
      'Sözcükte Anlam', 'Cümlede Anlam', 'Paragraf', 'Fiilimsiler',
      'Cümlenin Ögeleri', 'Fiilde Çatı', 'Cümle Çeşitleri',
      'Anlatım Bozuklukları', 'Yazım Kuralları', 'Noktalama İşaretleri',
    ],
    'sub_lgs_1': [ // LGS Matematik
      'Çarpanlar ve Katlar', 'Üslü İfadeler', 'Kareköklü İfadeler',
      'Veri Analizi', 'Olasılık', 'Cebirsel İfadeler', 'Denklemler',
      'Eşitsizlikler', 'Üçgenler', 'Eşlik ve Benzerlik', 'Dönüşüm Geometrisi',
      'Geometrik Cisimler',
    ],
    'sub_lgs_2': [ // LGS Fen
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
}
