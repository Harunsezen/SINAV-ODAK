/// MÜFREDAT VERİSİ (v1.2) — ders > sınıf > konu > alt dal.
///
/// ## Kaynak — ÖNCE OKU
///
/// Bu liste resmî bir belgeden **kopyalanmadı**. Geliştirme ortamının
/// dışarıya ağ erişimi kapalı: `mufredat.meb.gov.tr` ve `ttkb.meb.gov.tr`
/// `EGRESS_BLOCKED` dönüyor — ama kontrol olarak `example.com` de aynı
/// yanıtı veriyor, yani engel MEB'e özgü değil, **hiçbir** adrese
/// çıkılamıyor.
///
/// Liste bu yüzden MEB öğretim programları ve ÖSYM TYT/AYT kapsamına dair
/// bilgiden derlendi. Kapsam ve adlandırma büyük ölçüde doğru, ancak
/// **ünite adları yürürlükteki programla birebir aynı olmayabilir**.
/// Kullanıcıya "MEB müfredatı" diye sunulmadan önce bir insan gözüyle
/// karşılaştırılmalı. Ayrıntı: `V1_2.md > Müfredat kaynak özeti`.
///
/// ## Etiketler
///
/// - `grade` 5–12, sınıfa bağlı olmayan konularda `null`.
/// - `tag` `tyt`, `ayt` veya `tyt,ayt`.
///   TYT: 5–10. sınıf temeli + İnkılap + Felsefe girişi.
///   AYT: 11–12 derinliği.
///
/// ## Neden ayrı dosya
///
/// `seed_data.dart` katalog iskeleti (dersler, çalışma türleri); burası
/// **içerik**. İçerik büyüyecek ve sık düzenlenecek — iskeletle aynı
/// dosyada olsaydı her müfredat düzeltmesi tohumlama mantığını riske
/// atardı.
library;

import '../../domain/entities/enums.dart';

/// Bir müfredat konusu ve alt dalları.
class CurriculumTopic {
  const CurriculumTopic(this.name, {this.grade, this.tag, this.children});

  final String name;
  final int? grade;
  final String? tag;

  /// Alt dallar. Boşsa konu tek seviyeli.
  final List<String>? children;

  /// TYT/AYT etiketi olmadan aynı konu (LGS için).
  CurriculumTopic untagged() =>
      CurriculumTopic(name, grade: grade, children: children);

  /// Sınıf düzeyi ve etiket olmadan aynı konu (KPSS/ALES/DGS/diğer için).
  CurriculumTopic plain() => CurriculumTopic(name, children: children);
}

/// Ders adı → konular. Ders adları `seed_data.dart` ile BİREBİR aynı
/// olmalı; eşleşme ada göre kuruluyor (ID'ler sınav türüne göre değişiyor).
abstract final class CurriculumData {
  static const bySubject = <String, List<CurriculumTopic>>{
    // =================================================================
    // MATEMATİK — TYT tabanı 5–10, AYT derinliği 11–12
    // =================================================================
    'Matematik': [
      CurriculumTopic('Doğal Sayılar', grade: 5, tag: 'tyt'),
      CurriculumTopic(
        'Kesirler',
        grade: 5,
        tag: 'tyt',
        children: [
          'Kesirleri Karşılaştırma',
          'Kesirlerle Toplama Çıkarma',
          'Kesirlerle Çarpma Bölme',
        ],
      ),
      CurriculumTopic('Ondalık Gösterim', grade: 5, tag: 'tyt'),
      CurriculumTopic('Yüzdeler', grade: 5, tag: 'tyt'),
      CurriculumTopic(
        'Çarpanlar ve Katlar',
        grade: 6,
        tag: 'tyt',
        children: [
          'EBOB',
          'EKOK',
          'Asal Çarpanlara Ayırma',
        ],
      ),
      CurriculumTopic(
        'Oran ve Orantı',
        grade: 6,
        tag: 'tyt',
        children: [
          'Doğru Orantı',
          'Ters Orantı',
          'Orantı Problemleri',
        ],
      ),
      CurriculumTopic('Tam Sayılarla İşlemler', grade: 7, tag: 'tyt'),
      CurriculumTopic('Rasyonel Sayılar', grade: 7, tag: 'tyt'),
      CurriculumTopic(
        'Cebirsel İfadeler',
        grade: 7,
        tag: 'tyt',
        children: [
          'Özdeşlikler',
          'Çarpanlara Ayırma',
        ],
      ),
      CurriculumTopic(
        'Denklemler',
        grade: 7,
        tag: 'tyt',
        children: [
          'Birinci Dereceden Denklemler',
          'Denklem Kurma Problemleri',
        ],
      ),
      CurriculumTopic('Üslü İfadeler', grade: 8, tag: 'tyt'),
      CurriculumTopic('Kareköklü İfadeler', grade: 8, tag: 'tyt'),
      CurriculumTopic('Eşitsizlikler', grade: 8, tag: 'tyt'),
      CurriculumTopic('Olasılık', grade: 8, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Mantık',
        grade: 9,
        tag: 'tyt',
        children: [
          'Önermeler',
          'Bileşik Önermeler',
          'Açık Önermeler ve Niceleyiciler',
        ],
      ),
      CurriculumTopic(
        'Kümeler',
        grade: 9,
        tag: 'tyt',
        children: [
          'Kümelerde İşlemler',
          'Kartezyen Çarpım',
        ],
      ),
      CurriculumTopic('Temel Kavramlar', grade: 9, tag: 'tyt'),
      CurriculumTopic('Sayı Basamakları', grade: 9, tag: 'tyt'),
      CurriculumTopic(
        'Bölme ve Bölünebilme',
        grade: 9,
        tag: 'tyt',
        children: [
          'Bölünebilme Kuralları',
          'Kalan Bulma',
        ],
      ),
      CurriculumTopic('Mutlak Değer', grade: 9, tag: 'tyt'),
      CurriculumTopic(
        'Problemler',
        grade: 9,
        tag: 'tyt',
        children: [
          'Sayı Problemleri',
          'Yaş Problemleri',
          'İşçi Havuz Problemleri',
          'Hız Problemleri',
          'Yüzde Kâr Zarar Problemleri',
          'Karışım Problemleri',
        ],
      ),
      CurriculumTopic(
        'Fonksiyonlar',
        grade: 10,
        tag: 'tyt,ayt',
        children: [
          'Fonksiyon Çeşitleri',
          'Bileşke Fonksiyon',
          'Ters Fonksiyon',
        ],
      ),
      CurriculumTopic('Polinomlar', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic(
        'İkinci Dereceden Denklemler',
        grade: 10,
        tag: 'tyt,ayt',
        children: ['Kökler ve Diskriminant', 'Kökler Toplamı Çarpımı'],
      ),
      CurriculumTopic(
        'Permütasyon ve Kombinasyon',
        grade: 10,
        tag: 'tyt,ayt',
        children: ['Sayma Kuralları', 'Permütasyon', 'Kombinasyon', 'Binom'],
      ),
      CurriculumTopic(
        'Trigonometri',
        grade: 11,
        tag: 'ayt',
        children: [
          'Birim Çember',
          'Toplam Fark Formülleri',
          'Trigonometrik Denklemler',
          'Ters Trigonometrik Fonksiyonlar',
        ],
      ),
      CurriculumTopic(
        'Logaritma',
        grade: 12,
        tag: 'ayt',
        children: [
          'Logaritma Özellikleri',
          'Logaritmik Denklemler',
        ],
      ),
      CurriculumTopic(
        'Diziler',
        grade: 12,
        tag: 'ayt',
        children: [
          'Aritmetik Dizi',
          'Geometrik Dizi',
        ],
      ),
      CurriculumTopic('Limit ve Süreklilik', grade: 12, tag: 'ayt'),
      CurriculumTopic(
        'Türev',
        grade: 12,
        tag: 'ayt',
        children: [
          'Türev Alma Kuralları',
          'Zincir Kuralı',
          'Kapalı Fonksiyonun Türevi',
          'Ekstremum ve Grafik Çizimi',
          'Türev Uygulamaları',
        ],
      ),
      CurriculumTopic(
        'İntegral',
        grade: 12,
        tag: 'ayt',
        children: [
          'Belirsiz İntegral',
          'Belirli İntegral',
          'Alan ve Hacim Hesapları',
        ],
      ),
    ],

    // =================================================================
    // GEOMETRİ
    // =================================================================
    'Geometri': [
      CurriculumTopic('Temel Geometrik Kavramlar', grade: 9, tag: 'tyt'),
      CurriculumTopic('Doğruda Açılar', grade: 9, tag: 'tyt'),
      CurriculumTopic(
        'Üçgende Açılar',
        grade: 9,
        tag: 'tyt',
        children: [
          'İkizkenar ve Eşkenar Üçgen',
          'Açıortay ve Kenarortay',
          'Üçgen Eşitsizliği',
        ],
      ),
      CurriculumTopic('Üçgende Eşlik ve Benzerlik', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Dik Üçgen',
        grade: 9,
        tag: 'tyt,ayt',
        children: [
          'Pisagor Bağıntısı',
          'Öklid Bağıntıları',
          'Özel Dik Üçgenler',
        ],
      ),
      CurriculumTopic('Üçgende Alan', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic('Çokgenler', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Dörtgenler',
        grade: 10,
        tag: 'tyt,ayt',
        children: [
          'Paralelkenar',
          'Eşkenar Dörtgen',
          'Dikdörtgen ve Kare',
          'Yamuk',
          'Deltoid',
        ],
      ),
      CurriculumTopic(
        'Çember ve Daire',
        grade: 11,
        tag: 'tyt,ayt',
        children: [
          'Çemberde Açılar',
          'Çemberde Uzunluk',
          'Dairede Alan',
        ],
      ),
      CurriculumTopic(
        'Analitik Geometri',
        grade: 11,
        tag: 'ayt',
        children: [
          'Doğrunun Analitiği',
          'Çemberin Analitiği',
        ],
      ),
      CurriculumTopic(
        'Katı Cisimler',
        grade: 12,
        tag: 'ayt',
        children: [
          'Prizmalar',
          'Piramitler',
          'Silindir Koni Küre',
        ],
      ),
      CurriculumTopic('Dönüşüm Geometrisi', grade: 12, tag: 'ayt'),
    ],

    // =================================================================
    // TÜRKÇE — TYT ağırlıklı
    // =================================================================
    'Türkçe': [
      CurriculumTopic(
        'Sözcükte Anlam',
        grade: 5,
        tag: 'tyt',
        children: [
          'Gerçek Mecaz Terim Anlam',
          'Deyimler ve Atasözleri',
          'Söz Sanatları',
        ],
      ),
      CurriculumTopic('Cümlede Anlam', grade: 6, tag: 'tyt'),
      CurriculumTopic(
        'Paragraf',
        grade: 7,
        tag: 'tyt',
        children: [
          'Ana Düşünce',
          'Yardımcı Düşünce',
          'Paragrafta Yapı',
          'Anlatım Biçimleri',
        ],
      ),
      CurriculumTopic('Ses Bilgisi', grade: 8, tag: 'tyt'),
      CurriculumTopic('Yazım Kuralları', grade: 8, tag: 'tyt'),
      CurriculumTopic('Noktalama İşaretleri', grade: 8, tag: 'tyt'),
      CurriculumTopic(
        'Sözcük Türleri',
        grade: 9,
        tag: 'tyt',
        children: [
          'İsim',
          'Sıfat',
          'Zamir',
          'Zarf',
          'Edat Bağlaç Ünlem',
        ],
      ),
      CurriculumTopic(
        'Fiiller',
        grade: 9,
        tag: 'tyt',
        children: [
          'Fiilde Kip',
          'Fiilde Çatı',
          'Ek Fiil',
        ],
      ),
      CurriculumTopic('Fiilimsiler', grade: 10, tag: 'tyt'),
      CurriculumTopic('Cümlenin Ögeleri', grade: 10, tag: 'tyt'),
      CurriculumTopic('Cümle Türleri', grade: 10, tag: 'tyt'),
      CurriculumTopic('Anlatım Bozuklukları', grade: 11, tag: 'tyt'),
    ],

    // =================================================================
    // EDEBİYAT — AYT
    // =================================================================
    'Edebiyat': [
      CurriculumTopic('Güzel Sanatlar ve Edebiyat', grade: 9, tag: 'ayt'),
      CurriculumTopic(
        'Şiir Bilgisi',
        grade: 9,
        tag: 'ayt',
        children: [
          'Nazım Biçimleri',
          'Ölçü ve Uyak',
          'Söz Sanatları',
        ],
      ),
      CurriculumTopic(
        'Halk Edebiyatı',
        grade: 10,
        tag: 'ayt',
        children: [
          'Anonim Halk Edebiyatı',
          'Âşık Edebiyatı',
          'Dinî-Tasavvufi Halk Edebiyatı',
        ],
      ),
      CurriculumTopic(
        'Divan Edebiyatı',
        grade: 10,
        tag: 'ayt',
        children: [
          'Divan Şiiri Nazım Biçimleri',
          'Divan Nesri',
        ],
      ),
      CurriculumTopic('Tanzimat Edebiyatı', grade: 11, tag: 'ayt'),
      CurriculumTopic('Servet-i Fünûn', grade: 11, tag: 'ayt'),
      CurriculumTopic('Millî Edebiyat', grade: 11, tag: 'ayt'),
      CurriculumTopic(
        'Cumhuriyet Dönemi Edebiyatı',
        grade: 12,
        tag: 'ayt',
        children: ['Cumhuriyet Şiiri', 'Cumhuriyet Romanı', 'Öykü ve Tiyatro'],
      ),
      CurriculumTopic('Dünya Edebiyatı', grade: 12, tag: 'ayt'),
      CurriculumTopic('Edebî Akımlar', grade: 12, tag: 'ayt'),
    ],

    // =================================================================
    // FEN (5–8) — LGS ve TYT temeli
    // =================================================================
    'Fen Bilimleri': [
      CurriculumTopic('Güneş Dünya ve Ay', grade: 5),
      CurriculumTopic('Canlılar Dünyası', grade: 5),
      CurriculumTopic('Kuvvetin Ölçülmesi', grade: 5),
      CurriculumTopic('Madde ve Değişim', grade: 5),
      CurriculumTopic('Vücudumuzdaki Sistemler', grade: 6),
      CurriculumTopic('Işık ve Ses', grade: 6),
      CurriculumTopic('Elektriğin İletimi', grade: 6),
      CurriculumTopic('Hücre ve Bölünmeler', grade: 7),
      CurriculumTopic('Aynalarda Yansıma', grade: 7),
      CurriculumTopic('Mevsimler ve İklim', grade: 8),
      CurriculumTopic(
        'DNA ve Genetik Kod',
        grade: 8,
        children: [
          'Kalıtım',
          'Mutasyon ve Modifikasyon',
          'Adaptasyon',
        ],
      ),
      CurriculumTopic('Basınç', grade: 8),
      CurriculumTopic('Madde ve Endüstri', grade: 8),
      CurriculumTopic('Basit Makineler', grade: 8),
      CurriculumTopic('Enerji Dönüşümleri', grade: 8),
      CurriculumTopic('Elektrik Yükleri ve Elektrik Enerjisi', grade: 8),
    ],

    // =================================================================
    // FİZİK
    // =================================================================
    'Fizik': [
      CurriculumTopic('Fizik Bilimine Giriş', grade: 9, tag: 'tyt'),
      CurriculumTopic('Madde ve Özellikleri', grade: 9, tag: 'tyt'),
      CurriculumTopic(
        'Hareket ve Kuvvet',
        grade: 9,
        tag: 'tyt',
        children: [
          'Doğrusal Hareket',
          'Newton Yasaları',
          'Sürtünme Kuvveti',
        ],
      ),
      CurriculumTopic(
        'Enerji',
        grade: 9,
        tag: 'tyt,ayt',
        children: [
          'İş Güç Enerji',
          'Enerjinin Korunumu',
        ],
      ),
      CurriculumTopic('Isı ve Sıcaklık', grade: 9, tag: 'tyt'),
      CurriculumTopic('Elektrostatik', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Elektrik Akımı',
        grade: 10,
        tag: 'tyt,ayt',
        children: [
          'Ohm Yasası',
          'Devre Çözümleri',
        ],
      ),
      CurriculumTopic('Manyetizma', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Basınç ve Kaldırma Kuvveti',
        grade: 10,
        tag: 'tyt,ayt',
        children: [
          'Katı Basıncı',
          'Sıvı Basıncı',
          'Gaz Basıncı',
          'Kaldırma Kuvveti',
        ],
      ),
      CurriculumTopic('Dalgalar', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Optik',
        grade: 10,
        tag: 'tyt,ayt',
        children: [
          'Aynalar',
          'Mercekler',
        ],
      ),
      CurriculumTopic('Vektörler ve Bağıl Hareket', grade: 11, tag: 'ayt'),
      CurriculumTopic('Newton Hareket Yasaları', grade: 11, tag: 'ayt'),
      CurriculumTopic('İtme ve Momentum', grade: 11, tag: 'ayt'),
      CurriculumTopic('Tork ve Denge', grade: 11, tag: 'ayt'),
      CurriculumTopic('Düzgün Çembersel Hareket', grade: 12, tag: 'ayt'),
      CurriculumTopic('Basit Harmonik Hareket', grade: 12, tag: 'ayt'),
      CurriculumTopic('Dalga Mekaniği', grade: 12, tag: 'ayt'),
      CurriculumTopic(
        'Modern Fizik',
        grade: 12,
        tag: 'ayt',
        children: [
          'Özel Görelilik',
          'Fotoelektrik Olay',
          'Atom Modelleri',
        ],
      ),
    ],

    // =================================================================
    // KİMYA
    // =================================================================
    'Kimya': [
      CurriculumTopic('Kimya Bilimi', grade: 9, tag: 'tyt'),
      CurriculumTopic(
        'Atom ve Periyodik Sistem',
        grade: 9,
        tag: 'tyt,ayt',
        children: ['Atom Modelleri', 'Periyodik Özellikler'],
      ),
      CurriculumTopic(
        'Kimyasal Türler Arası Etkileşim',
        grade: 9,
        tag: 'tyt,ayt',
        children: ['Güçlü Etkileşimler', 'Zayıf Etkileşimler'],
      ),
      CurriculumTopic('Maddenin Hâlleri', grade: 9, tag: 'tyt'),
      CurriculumTopic('Doğa ve Kimya', grade: 9, tag: 'tyt'),
      CurriculumTopic('Kimyanın Temel Kanunları', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic('Mol Kavramı', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic('Karışımlar', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic('Asitler Bazlar ve Tuzlar', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic('Modern Atom Teorisi', grade: 11, tag: 'ayt'),
      CurriculumTopic('Gazlar', grade: 11, tag: 'ayt'),
      CurriculumTopic('Sıvı Çözeltiler', grade: 11, tag: 'ayt'),
      CurriculumTopic('Kimyasal Tepkimelerde Enerji', grade: 11, tag: 'ayt'),
      CurriculumTopic('Tepkime Hızı ve Denge', grade: 11, tag: 'ayt'),
      CurriculumTopic('Kimya ve Elektrik', grade: 12, tag: 'ayt'),
      CurriculumTopic(
        'Organik Kimya',
        grade: 12,
        tag: 'ayt',
        children: [
          'Hidrokarbonlar',
          'Alkoller ve Eterler',
          'Karbonil Bileşikleri',
        ],
      ),
    ],

    // =================================================================
    // BİYOLOJİ
    // =================================================================
    'Biyoloji': [
      CurriculumTopic(
        'Yaşam Bilimi Biyoloji',
        grade: 9,
        tag: 'tyt',
        children: [
          'Canlıların Ortak Özellikleri',
          'Canlıların Yapısındaki Bileşikler',
        ],
      ),
      CurriculumTopic(
        'Hücre',
        grade: 9,
        tag: 'tyt,ayt',
        children: [
          'Hücre Organelleri',
          'Madde Geçişleri',
        ],
      ),
      CurriculumTopic(
        'Canlılar Dünyası',
        grade: 9,
        tag: 'tyt',
        children: ['Canlıların Sınıflandırılması', 'Canlı Âlemleri'],
      ),
      CurriculumTopic(
        'Hücre Bölünmeleri',
        grade: 10,
        tag: 'tyt,ayt',
        children: ['Mitoz', 'Mayoz'],
      ),
      CurriculumTopic(
        'Kalıtım',
        grade: 10,
        tag: 'tyt,ayt',
        children: [
          'Mendel Genetiği',
          'Kan Grupları',
          'Eşeye Bağlı Kalıtım',
        ],
      ),
      CurriculumTopic('Ekosistem Ekolojisi', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic(
        'İnsan Fizyolojisi',
        grade: 11,
        tag: 'ayt',
        children: [
          'Sinir Sistemi',
          'Endokrin Sistem',
          'Duyu Organları',
          'Destek ve Hareket Sistemi',
          'Sindirim Sistemi',
          'Dolaşım ve Bağışıklık',
          'Solunum Sistemi',
          'Boşaltım Sistemi',
          'Üreme Sistemi',
        ],
      ),
      CurriculumTopic('Komünite ve Popülasyon', grade: 11, tag: 'ayt'),
      CurriculumTopic(
        'Genden Proteine',
        grade: 12,
        tag: 'ayt',
        children: [
          'Nükleik Asitler',
          'Protein Sentezi',
        ],
      ),
      CurriculumTopic(
        'Canlılarda Enerji Dönüşümleri',
        grade: 12,
        tag: 'ayt',
        children: ['Fotosentez', 'Kemosentez', 'Solunum'],
      ),
      CurriculumTopic('Bitki Biyolojisi', grade: 12, tag: 'ayt'),
      CurriculumTopic('Canlılar ve Çevre', grade: 12, tag: 'ayt'),
    ],

    // =================================================================
    // TARİH — 9/10 TYT+AYT temeli, 11/12 AYT derinliği
    // =================================================================
    'Tarih': [
      CurriculumTopic('Tarih ve Zaman', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic('İnsanlığın İlk Dönemleri', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic('Orta Çağ\'da Dünya', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic(
        'İlk ve Orta Çağlarda Türk Dünyası',
        grade: 9,
        tag: 'tyt,ayt',
        children: [
          'Orta Asya\'da Kurulan İlk Türk Devletleri',
          'Kavimler Göçü',
          'Uygurlar ve Diğer Türk Toplulukları',
        ],
      ),
      CurriculumTopic('İslam Medeniyetinin Doğuşu', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Türklerin İslamiyet\'i Kabulü',
        grade: 9,
        tag: 'tyt,ayt',
        children: [
          'Karahanlılar ve Gazneliler',
          'Büyük Selçuklu Devleti',
          'Anadolu Selçuklu Devleti',
        ],
      ),
      CurriculumTopic('Beylikten Devlete Osmanlı', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic('Beylikten Cihan Devletine', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Dünya Gücü Osmanlı',
        grade: 10,
        tag: 'tyt,ayt',
        children: [
          'Osmanlı Merkez Teşkilatı',
          'Osmanlı Toplum Düzeni',
          'Osmanlı Ekonomisi',
        ],
      ),
      CurriculumTopic('Değişen Dünya Dengeleri', grade: 11, tag: 'ayt'),
      CurriculumTopic(
        'Değişim Çağında Avrupa ve Osmanlı',
        grade: 11,
        tag: 'ayt',
      ),
      CurriculumTopic(
        'Uluslararası İlişkilerde Denge Stratejisi',
        grade: 11,
        tag: 'ayt',
      ),
      CurriculumTopic(
        'Devrimler Çağında Değişen Devlet-Toplum İlişkileri',
        grade: 11,
        tag: 'ayt',
        children: ['Tanzimat ve Islahat', 'I. ve II. Meşrutiyet'],
      ),
      CurriculumTopic(
        'XX. Yüzyıl Başlarında Osmanlı ve Dünya',
        grade: 12,
        tag: 'tyt,ayt',
      ),
      CurriculumTopic(
        'Millî Mücadele',
        grade: 12,
        tag: 'tyt,ayt',
        children: [
          'Cemiyetler',
          'Kongreler',
          'TBMM\'nin Açılışı',
          'Cepheler',
          'Lozan Barış Antlaşması',
        ],
      ),
      CurriculumTopic(
        'Atatürkçülük ve Türk İnkılabı',
        grade: 12,
        tag: 'tyt,ayt',
        children: [
          'Siyasi İnkılaplar',
          'Hukuk ve Eğitim İnkılapları',
          'Atatürk İlkeleri',
          'Atatürk Dönemi Dış Politika',
        ],
      ),
      CurriculumTopic(
        'İki Savaş Arasında Türkiye ve Dünya',
        grade: 12,
        tag: 'ayt',
      ),
      CurriculumTopic('II. Dünya Savaşı ve Türkiye', grade: 12, tag: 'ayt'),
      CurriculumTopic('Soğuk Savaş Dönemi', grade: 12, tag: 'ayt'),
      CurriculumTopic('Yumuşama Dönemi ve Sonrası', grade: 12, tag: 'ayt'),
      CurriculumTopic('Küreselleşen Dünya', grade: 12, tag: 'ayt'),
    ],

    // =================================================================
    // COĞRAFYA
    // =================================================================
    'Coğrafya': [
      CurriculumTopic('Doğa ve İnsan', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Dünya\'nın Şekli ve Hareketleri',
        grade: 9,
        tag: 'tyt,ayt',
      ),
      CurriculumTopic('Coğrafi Konum', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Harita Bilgisi',
        grade: 9,
        tag: 'tyt,ayt',
        children: ['Ölçek', 'İzohips', 'Projeksiyonlar'],
      ),
      CurriculumTopic(
        'İklim Bilgisi',
        grade: 9,
        tag: 'tyt,ayt',
        children: [
          'Sıcaklık',
          'Basınç ve Rüzgârlar',
          'Nem ve Yağış',
          'İklim Tipleri',
        ],
      ),
      CurriculumTopic('İç Kuvvetler', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic('Dış Kuvvetler', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic('Nüfus', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic('Göç', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic('Yerleşme', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic('Doğal Afetler', grade: 9, tag: 'tyt,ayt'),
      CurriculumTopic('Kayaçlar ve Yer Şekilleri', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic('Su Kaynakları', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic('Toprak ve Bitki Örtüsü', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic('Nüfus Politikaları', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Türkiye\'nin Fiziki Coğrafyası',
        grade: 10,
        tag: 'tyt,ayt',
      ),
      CurriculumTopic(
        'Türkiye\'de Nüfus ve Yerleşme',
        grade: 10,
        tag: 'tyt,ayt',
      ),
      CurriculumTopic(
        'Bölge ve Ülke Sınıflandırması',
        grade: 10,
        tag: 'tyt,ayt',
      ),
      CurriculumTopic('Biyoçeşitlilik ve Ekosistem', grade: 11, tag: 'ayt'),
      CurriculumTopic('Şehirler ve Etki Alanları', grade: 11, tag: 'ayt'),
      CurriculumTopic(
        'Ekonomik Faaliyetler',
        grade: 11,
        tag: 'ayt',
        children: [
          'Tarım ve Hayvancılık',
          'Madencilik ve Enerji',
          'Sanayi',
          'Ulaşım',
          'Turizm',
        ],
      ),
      CurriculumTopic(
        'Türkiye\'nin Ekonomi Politikaları',
        grade: 11,
        tag: 'ayt',
      ),
      CurriculumTopic('Küresel Ticaret', grade: 12, tag: 'ayt'),
      CurriculumTopic('Türkiye\'nin Jeopolitik Konumu', grade: 12, tag: 'ayt'),
      CurriculumTopic('Türk Kültür Bölgeleri', grade: 12, tag: 'ayt'),
      CurriculumTopic('Bölgesel Örgütler', grade: 12, tag: 'ayt'),
      CurriculumTopic('Çevre Sorunları ve Yönetimi', grade: 12, tag: 'ayt'),
      CurriculumTopic(
        'Doğal Kaynakların Sürdürülebilir Kullanımı',
        grade: 12,
        tag: 'ayt',
      ),
    ],

    // =================================================================
    // FELSEFE GRUBU — felsefe TYT+AYT, psikoloji/sosyoloji/mantık AYT
    // =================================================================
    'Felsefe': [
      CurriculumTopic('Felsefeyi Tanıma', grade: 10, tag: 'tyt,ayt'),
      CurriculumTopic(
        'Felsefenin Temel Konuları',
        grade: 10,
        tag: 'tyt,ayt',
        children: [
          'Bilgi Felsefesi',
          'Varlık Felsefesi',
          'Ahlak Felsefesi',
          'Sanat Felsefesi',
          'Din Felsefesi',
          'Siyaset Felsefesi',
          'Bilim Felsefesi',
        ],
      ),
      CurriculumTopic(
        'Felsefe Tarihi',
        grade: 10,
        tag: 'tyt,ayt',
        children: [
          'İlk Çağ Felsefesi',
          'Orta Çağ Felsefesi',
          '15.-17. Yüzyıl Felsefesi',
          '18.-19. Yüzyıl Felsefesi',
          '20. Yüzyıl Felsefesi',
        ],
      ),
      CurriculumTopic(
        'Psikoloji',
        grade: 11,
        tag: 'ayt',
        children: [
          'Psikolojinin Temelleri',
          'Duyum ve Algı',
          'Öğrenme Bellek Güdü',
          'Ruh Sağlığının Temelleri',
        ],
      ),
      CurriculumTopic(
        'Sosyoloji',
        grade: 11,
        tag: 'ayt',
        children: [
          'Toplum ve Birey',
          'Toplumsal Kurumlar',
          'Toplumsal Değişme ve Gelişme',
          'Toplumsal Tabakalaşma',
        ],
      ),
      CurriculumTopic(
        'Mantık',
        grade: 11,
        tag: 'ayt',
        children: [
          'Klasik Mantık',
          'Önermeler ve Çıkarım',
          'Sembolik Mantık',
        ],
      ),
    ],

    // =================================================================
    // T.C. İNKILAP TARİHİ — LGS (8. sınıf)
    // =================================================================
    'T.C. İnkılap Tarihi': [
      CurriculumTopic('Bir Kahraman Doğuyor', grade: 8),
      CurriculumTopic(
        'Millî Uyanış: Bağımsızlık Yolunda Atılan Adımlar',
        grade: 8,
        children: ['Cemiyetler', 'Kongreler', 'Misak-ı Millî'],
      ),
      CurriculumTopic(
        'Millî Bir Destan: Ya İstiklal Ya Ölüm',
        grade: 8,
        children: ['Cepheler', 'Sakarya Meydan Muharebesi', 'Büyük Taarruz'],
      ),
      CurriculumTopic(
        'Atatürkçülük ve Çağdaşlaşan Türkiye',
        grade: 8,
        children: ['İnkılaplar', 'Atatürk İlkeleri'],
      ),
      CurriculumTopic('Demokratikleşme Çabaları', grade: 8),
      CurriculumTopic('Atatürk Dönemi Türk Dış Politikası', grade: 8),
      CurriculumTopic('Atatürk\'ün Ölümü ve Sonrası', grade: 8),
    ],

    // =================================================================
    // DİN KÜLTÜRÜ VE AHLAK BİLGİSİ — 5–12
    // =================================================================
    'Din Kültürü': [
      CurriculumTopic('Allah İnancı', grade: 5),
      CurriculumTopic('Ramazan ve Oruç', grade: 5),
      CurriculumTopic('Adap ve Nezaket', grade: 5),
      CurriculumTopic('Peygamber ve İlahi Kitap İnancı', grade: 6),
      CurriculumTopic('Namaz', grade: 6),
      CurriculumTopic('Zararlı Alışkanlıklar', grade: 6),
      CurriculumTopic('Melek ve Ahiret İnancı', grade: 7),
      CurriculumTopic('Hac ve Kurban', grade: 7),
      CurriculumTopic('Ahlaki Davranışlar', grade: 7),
      CurriculumTopic('Kader İnancı', grade: 8),
      CurriculumTopic('Zekât ve Sadaka', grade: 8),
      CurriculumTopic('Din ve Hayat', grade: 8),
      CurriculumTopic('Hz. Muhammed\'in Örnekliği', grade: 8),
      CurriculumTopic('Bilgi ve İnanç', grade: 9, tag: 'tyt'),
      CurriculumTopic('Din ve İslam', grade: 9, tag: 'tyt'),
      CurriculumTopic('İslam ve İbadet', grade: 9, tag: 'tyt'),
      CurriculumTopic('Gençlik ve Değerler', grade: 9, tag: 'tyt'),
      CurriculumTopic('Allah-İnsan İlişkisi', grade: 10, tag: 'tyt'),
      CurriculumTopic('Din ve Aile', grade: 10, tag: 'tyt'),
      CurriculumTopic(
        'İslam Düşüncesinde Yorumlar',
        grade: 10,
        tag: 'tyt',
        children: ['İtikadi Yorumlar', 'Ameli Yorumlar'],
      ),
      CurriculumTopic('Dünya ve Ahiret', grade: 11, tag: 'tyt'),
      CurriculumTopic('Kur\'an\'a Göre Hz. Muhammed', grade: 11, tag: 'tyt'),
      CurriculumTopic('İnançla İlgili Meseleler', grade: 11, tag: 'tyt'),
      CurriculumTopic('Yahudilik ve Hıristiyanlık', grade: 11, tag: 'tyt'),
      CurriculumTopic('İslam ve Bilim', grade: 12, tag: 'tyt'),
      CurriculumTopic('Anadolu\'da İslam', grade: 12, tag: 'tyt'),
      CurriculumTopic(
        'İslam Düşüncesinde Tasavvufi Yorumlar',
        grade: 12,
        tag: 'tyt',
      ),
      CurriculumTopic('Güncel Dinî Meseleler', grade: 12, tag: 'tyt'),
      CurriculumTopic('Hint ve Çin Dinleri', grade: 12, tag: 'tyt'),
    ],

    // =================================================================
    // İNGİLİZCE — 5–12
    //
    // Etiket YOK: YKS'de İngilizce ayrı bir oturumdur (YDT), TYT/AYT
    // testlerinde yer almaz. Yanlış etiket, seviye sekmesinde yanlış
    // vaat olurdu.
    // =================================================================
    'İngilizce': [
      CurriculumTopic('Present Simple', grade: 5),
      CurriculumTopic('Can / Can\'t (Ability)', grade: 5),
      CurriculumTopic('Prepositions of Place', grade: 5),
      CurriculumTopic('Present Continuous', grade: 6),
      CurriculumTopic('Countable / Uncountable', grade: 6),
      CurriculumTopic('Comparatives and Superlatives', grade: 6),
      CurriculumTopic('Past Simple', grade: 7),
      CurriculumTopic('Future: will / be going to', grade: 7),
      CurriculumTopic('Modals: must / have to / should', grade: 7),
      CurriculumTopic('Present Perfect', grade: 8),
      CurriculumTopic('Conditionals Type 1', grade: 8),
      CurriculumTopic('Too / Enough', grade: 8),
      CurriculumTopic(
        'Tenses Review',
        grade: 9,
        children: ['Simple Tenses', 'Continuous Tenses', 'Perfect Tenses'],
      ),
      CurriculumTopic('Question Forms', grade: 9),
      CurriculumTopic('Passive Voice', grade: 10),
      CurriculumTopic('Relative Clauses', grade: 10),
      CurriculumTopic('Reported Speech', grade: 11),
      CurriculumTopic('Noun Clauses', grade: 11),
      CurriculumTopic('Gerunds and Infinitives', grade: 11),
      CurriculumTopic('Conditionals (All Types)', grade: 11),
      CurriculumTopic(
        'Sınav Teknikleri',
        grade: 12,
        children: [
          'Cloze Test',
          'Cümle Tamamlama',
          'Çeviri',
          'Paragraf Tamamlama',
          'Anlamca En Yakın Cümle',
          'Akışı Bozan Cümle',
        ],
      ),
      CurriculumTopic('Kelime Bilgisi', grade: 12),
      CurriculumTopic('Okuma Parçaları', grade: 12),
    ],

    // =================================================================
    // SIFIR KONULU DERS KALMASIN (koordinatör kuralı)
    //
    // Aşağıdakiler akademik ders değil, çalışma kabı. Yine de en az bir
    // konuları var: konusuz ders, konu seçme ekranını boş bırakıyor ve
    // oturum kurulumunu çıkmaza sokuyordu.
    // =================================================================
    'Sayısal': [
      CurriculumTopic('Temel Kavramlar'),
      CurriculumTopic('Sayılar ve Bölünebilme'),
      CurriculumTopic('Rasyonel Sayılar ve Ondalık Gösterim'),
      CurriculumTopic('Denklem Çözme'),
      CurriculumTopic(
        'Problemler',
        children: [
          'Sayı Problemleri',
          'Yaş Problemleri',
          'İşçi ve Havuz Problemleri',
          'Hız Problemleri',
          'Yüzde Kâr Zarar',
          'Karışım Problemleri',
        ],
      ),
      CurriculumTopic('Kümeler ve Fonksiyonlar'),
      CurriculumTopic('İşlem ve Modüler Aritmetik'),
      CurriculumTopic('Permütasyon Kombinasyon Olasılık'),
      CurriculumTopic('Sayısal Mantık'),
      CurriculumTopic('Tablo ve Grafik Yorumlama'),
      CurriculumTopic(
        'Geometri',
        children: [
          'Açılar',
          'Üçgenler',
          'Dörtgenler',
          'Çember ve Daire',
          'Analitik Geometri',
          'Katı Cisimler',
        ],
      ),
    ],
    'Sözel': [
      CurriculumTopic('Sözcükte Anlam'),
      CurriculumTopic('Cümlede Anlam'),
      CurriculumTopic(
        'Paragraf',
        children: [
          'Ana Düşünce',
          'Yardımcı Düşünce',
          'Paragrafta Yapı',
          'Anlatım Biçimleri',
        ],
      ),
      CurriculumTopic('Sözel Mantık'),
      CurriculumTopic('Anlatım Bozukluğu'),
    ],
    'Vatandaşlık': [
      CurriculumTopic('Hukukun Temel Kavramları'),
      CurriculumTopic('Devlet Biçimleri ve Hükümet Sistemleri'),
      CurriculumTopic('Türk Anayasa Tarihi'),
      CurriculumTopic('1982 Anayasası\'nın Temel İlkeleri'),
      CurriculumTopic('Temel Hak ve Hürriyetler'),
      CurriculumTopic(
        'Devletin Temel Organları',
        children: ['Yasama', 'Yürütme', 'Yargı'],
      ),
      CurriculumTopic('İdare Hukuku'),
      CurriculumTopic('Uluslararası Kuruluşlar'),
    ],
    'Güncel Bilgiler': [
      CurriculumTopic('Türkiye Gündemi'),
      CurriculumTopic('Dünya Gündemi'),
      CurriculumTopic('Uluslararası Kuruluşlar'),
      CurriculumTopic('Bilim ve Teknoloji'),
      CurriculumTopic('Kültür ve Spor'),
    ],
    'Eğitim Bilimleri': [
      CurriculumTopic(
        'Gelişim Psikolojisi',
        children: [
          'Bilişsel Gelişim',
          'Ahlak Gelişimi',
          'Kişilik Gelişimi',
          'Dil Gelişimi',
        ],
      ),
      CurriculumTopic(
        'Öğrenme Psikolojisi',
        children: [
          'Davranışçı Kuramlar',
          'Bilişsel Kuramlar',
          'Sosyal Öğrenme Kuramı',
        ],
      ),
      CurriculumTopic('Rehberlik ve Özel Eğitim'),
      CurriculumTopic('Öğretim İlke ve Yöntemleri'),
      CurriculumTopic('Program Geliştirme'),
      CurriculumTopic('Ölçme ve Değerlendirme'),
      CurriculumTopic('Sınıf Yönetimi'),
      CurriculumTopic('Öğretim Teknolojileri ve Materyal Tasarımı'),
    ],
    'Genel Çalışma': [
      CurriculumTopic('Konu Çalışması'),
      CurriculumTopic('Genel Tekrar'),
      CurriculumTopic('Soru Çözümü'),
      CurriculumTopic('Okuma'),
    ],
    'Diğer': [
      CurriculumTopic('Genel Tekrar'),
      CurriculumTopic('Serbest Çalışma'),
      CurriculumTopic('Ödev'),
    ],
    'Deneme': [
      CurriculumTopic('Genel Deneme'),
      CurriculumTopic('Branş Denemesi'),
    ],
  };

  /// Sınava özgü listeler. Anahtar `'<exam>:<ders adı>'`.
  ///
  /// Aynı ders adı sınavdan sınava farklı içerik demek olabiliyor:
  /// KPSS Türkçesi sınıf düzeyine bağlı değil, LGS denemesi TYT/AYT
  /// denemesi değil. Ad üzerinden tek liste paylaşmak yanlış vaat olurdu.
  static const _overrides = <String, List<CurriculumTopic>>{
    'yks:TYT Genel': [
      CurriculumTopic('TYT Türkçe', tag: 'tyt'),
      CurriculumTopic(
        'TYT Sosyal Bilimler',
        tag: 'tyt',
        children: ['Tarih', 'Coğrafya', 'Felsefe', 'Din Kültürü'],
      ),
      CurriculumTopic('TYT Temel Matematik', tag: 'tyt'),
      CurriculumTopic(
        'TYT Fen Bilimleri',
        tag: 'tyt',
        children: ['Fizik', 'Kimya', 'Biyoloji'],
      ),
    ],
    'yks:AYT Genel': [
      CurriculumTopic('AYT Matematik', tag: 'ayt'),
      CurriculumTopic('AYT Fizik', tag: 'ayt'),
      CurriculumTopic('AYT Kimya', tag: 'ayt'),
      CurriculumTopic('AYT Biyoloji', tag: 'ayt'),
      CurriculumTopic('AYT Türk Dili ve Edebiyatı', tag: 'ayt'),
      CurriculumTopic('AYT Tarih', tag: 'ayt'),
      CurriculumTopic('AYT Coğrafya', tag: 'ayt'),
      CurriculumTopic(
        'AYT Felsefe Grubu',
        tag: 'ayt',
        children: ['Felsefe', 'Psikoloji', 'Sosyoloji', 'Mantık'],
      ),
    ],
    'yks:Deneme': [
      CurriculumTopic('TYT Denemesi', tag: 'tyt'),
      CurriculumTopic('AYT Denemesi', tag: 'ayt'),
      CurriculumTopic('Branş Denemesi'),
    ],
    // LGS Türkçe/Matematik sınıf süzgeciyle çıkmıyordu: 8. sınıf dil
    // bilgisi ve geometri, YKS listesinde 9–12'ye yazılı. Süzgeç bunları
    // eleyip LGS adayını yarım müfredatla bırakırdı — bu yüzden kendi
    // listeleri var.
    'lgs:Türkçe': [
      CurriculumTopic(
        'Sözcükte Anlam',
        grade: 5,
        children: ['Gerçek Mecaz Terim Anlam', 'Deyimler ve Atasözleri'],
      ),
      CurriculumTopic('Cümlede Anlam', grade: 6),
      CurriculumTopic('Ses Bilgisi', grade: 6),
      CurriculumTopic(
        'Paragraf',
        grade: 7,
        children: [
          'Ana Düşünce',
          'Yardımcı Düşünce',
          'Paragrafta Yapı',
          'Anlatım Biçimleri',
        ],
      ),
      CurriculumTopic('Sözcük Türleri', grade: 7),
      CurriculumTopic('Söz Sanatları', grade: 8),
      CurriculumTopic('Fiilimsiler', grade: 8),
      CurriculumTopic('Cümlenin Ögeleri', grade: 8),
      CurriculumTopic('Fiilde Çatı', grade: 8),
      CurriculumTopic('Cümle Türleri', grade: 8),
      CurriculumTopic('Anlatım Bozuklukları', grade: 8),
      CurriculumTopic('Yazım Kuralları', grade: 8),
      CurriculumTopic('Noktalama İşaretleri', grade: 8),
    ],
    'lgs:Matematik': [
      CurriculumTopic('Doğal Sayılar', grade: 5),
      CurriculumTopic('Kesirler', grade: 5),
      CurriculumTopic('Ondalık Gösterim', grade: 5),
      CurriculumTopic('Yüzdeler', grade: 5),
      CurriculumTopic('Oran ve Orantı', grade: 6),
      CurriculumTopic('Tam Sayılarla İşlemler', grade: 7),
      CurriculumTopic('Rasyonel Sayılar', grade: 7),
      CurriculumTopic('Cebirsel İfadeler', grade: 7),
      CurriculumTopic('Denklemler', grade: 7),
      CurriculumTopic(
        'Çarpanlar ve Katlar',
        grade: 8,
        children: ['EBOB', 'EKOK', 'Asal Çarpanlara Ayırma'],
      ),
      CurriculumTopic('Üslü İfadeler', grade: 8),
      CurriculumTopic('Kareköklü İfadeler', grade: 8),
      CurriculumTopic('Veri Analizi', grade: 8),
      CurriculumTopic('Olasılık', grade: 8),
      CurriculumTopic('Cebirsel İfadeler ve Özdeşlikler', grade: 8),
      CurriculumTopic('Doğrusal Denklemler', grade: 8),
      CurriculumTopic('Eşitsizlikler', grade: 8),
      CurriculumTopic(
        'Üçgenler',
        grade: 8,
        children: [
          'Üçgende Açılar',
          'Üçgen Eşitsizliği',
          'Pisagor Bağıntısı',
        ],
      ),
      CurriculumTopic('Eşlik ve Benzerlik', grade: 8),
      CurriculumTopic('Dönüşüm Geometrisi', grade: 8),
      CurriculumTopic('Geometrik Cisimler', grade: 8),
    ],
    'lgs:Deneme': [
      CurriculumTopic('LGS Denemesi'),
      CurriculumTopic('Branş Denemesi'),
    ],
    'kpss:Deneme': [
      CurriculumTopic('Genel Yetenek - Genel Kültür Denemesi'),
      CurriculumTopic('Eğitim Bilimleri Denemesi'),
      CurriculumTopic('Branş Denemesi'),
    ],
    'kpss:Türkçe': [
      CurriculumTopic('Sözcükte Anlam'),
      CurriculumTopic('Cümlede Anlam'),
      CurriculumTopic(
        'Paragraf',
        children: [
          'Ana Düşünce',
          'Yardımcı Düşünce',
          'Paragrafta Yapı',
          'Anlatım Biçimleri',
        ],
      ),
      CurriculumTopic('Ses Bilgisi'),
      CurriculumTopic('Yazım Kuralları'),
      CurriculumTopic('Noktalama İşaretleri'),
      CurriculumTopic(
        'Dil Bilgisi',
        children: [
          'Sözcük Türleri',
          'Fiilimsiler',
          'Cümlenin Ögeleri',
          'Cümle Türleri',
          'Fiilde Çatı',
        ],
      ),
      CurriculumTopic('Anlatım Bozukluğu'),
    ],
    'kpss:Matematik': [
      CurriculumTopic('Temel Kavramlar'),
      CurriculumTopic('Sayı Basamakları'),
      CurriculumTopic('Bölme ve Bölünebilme'),
      CurriculumTopic('EBOB - EKOK'),
      CurriculumTopic('Rasyonel Sayılar'),
      CurriculumTopic('Basit Eşitsizlikler'),
      CurriculumTopic('Mutlak Değer'),
      CurriculumTopic('Üslü ve Köklü Sayılar'),
      CurriculumTopic('Çarpanlara Ayırma'),
      CurriculumTopic('Oran ve Orantı'),
      CurriculumTopic(
        'Problemler',
        children: [
          'Sayı Problemleri',
          'Yaş Problemleri',
          'İşçi ve Havuz Problemleri',
          'Hız Problemleri',
          'Yüzde Kâr Zarar',
          'Karışım Problemleri',
          'Grafik Problemleri',
        ],
      ),
      CurriculumTopic('Kümeler'),
      CurriculumTopic('Permütasyon Kombinasyon Olasılık'),
      CurriculumTopic('Sayısal Mantık'),
      CurriculumTopic(
        'Geometri',
        children: [
          'Açılar',
          'Üçgenler',
          'Dörtgenler',
          'Çember ve Daire',
          'Analitik Geometri',
          'Katı Cisimler',
        ],
      ),
    ],
  };

  /// Bir dersin, o SINAVA göre süzülmüş müfredatı.
  ///
  /// Süzme kuralları:
  /// - **YKS** → liste olduğu gibi (sınıf + TYT/AYT etiketi anlamlı).
  /// - **LGS** → yalnızca 5–8. sınıf; TYT/AYT etiketi DÜŞÜRÜLÜR
  ///   (LGS'de böyle bir oturum yok, etiket yanlış vaat olurdu).
  /// - **Diğerleri** (KPSS/ALES/DGS/diğer) → sınıf ve etiket düşürülür;
  ///   içerik aynı kalır. KPSS adayına "9. sınıf" demek anlamsız.
  ///
  /// Bilinmeyen ders için boş liste döner — çağıran taraf o dersi
  /// tohumlamayı atlar, çökmez.
  static List<CurriculumTopic> forSubject(ExamType exam, String subjectName) {
    final override = _overrides['${exam.name}:$subjectName'];
    if (override != null) return override;

    final base = bySubject[subjectName];
    if (base == null) return const [];

    return switch (exam) {
      ExamType.yks => base,
      ExamType.lgs => [
          for (final t in base)
            if (t.grade == null || t.grade! <= 8) t.untagged(),
        ],
      _ => [for (final t in base) t.plain()],
    };
  }
}
