import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/presentation/session_setup/setup_controller.dart';

/// v1.2/D — çoklu konu seçiminin SAF mantığı.
///
/// Veritabanı yok, widget yok: "hangi konular seçili ve hangisi birincil"
/// sorusu tek başına test ediliyor. Ekran testi bunun arayüze
/// bağlandığını doğruluyor, kuralın kendisini değil.
void main() {
  late ProviderContainer c;

  setUp(() {
    c = ProviderContainer();
    addTearDown(c.dispose);
  });

  SetupSelection get() => c.read(setupProvider);
  SetupNotifier n() => c.read(setupProvider.notifier);

  void pickSubject() => n().selectSubject(
        id: 'sub_yks_1',
        name: 'Matematik',
        colorHex: '#4F5BD5',
      );

  group('tek konu — v1.1 davranışı KORUNUYOR', () {
    test('selectTopic tek konu bırakıyor', () {
      pickSubject();
      n().selectTopic(id: 't1', name: 'Türev');

      expect(get().topicIds, ['t1']);
      expect(get().topicId, 't1');
      expect(get().topicName, 'Türev');
      expect(get().extraTopicCount, 0);
    });

    test('ikinci selectTopic ÖNCEKİNİ değiştiriyor, eklemiyor', () {
      // Satıra dokunmak "bunu seç ve ilerle" demek; birikmemeli.
      pickSubject();
      n().selectTopic(id: 't1', name: 'Türev');
      n().selectTopic(id: 't2', name: 'İntegral');

      expect(get().topicIds, ['t2']);
      expect(get().topicName, 'İntegral');
    });

    test('konusuz: liste boş, birincil null', () {
      pickSubject();
      expect(get().topicIds, isEmpty);
      expect(get().topicId, isNull);
      expect(get().topicName, isNull);
      expect(get().extraTopicCount, 0);
    });

    test('ders değişince konu seçimi DÜŞÜYOR', () {
      // Başka dersin konusuyla oturum başlatmak veri hatası olurdu.
      pickSubject();
      n().selectTopic(id: 't1', name: 'Türev');
      n().selectSubject(id: 'sub_yks_5', name: 'Biyoloji', colorHex: '#0A0');

      expect(get().topicIds, isEmpty);
    });
  });

  group('çoklu konu', () {
    test('toggleTopic ekliyor, SIRA korunuyor', () {
      pickSubject();
      n().toggleTopic(id: 't1', name: 'Türev');
      n().toggleTopic(id: 't2', name: 'İntegral');
      n().toggleTopic(id: 't3', name: 'Limit ve Süreklilik');

      expect(get().topicIds, ['t1', 't2', 't3']);
      expect(get().topicNames, ['Türev', 'İntegral', 'Limit ve Süreklilik']);
      expect(get().topicId, 't1', reason: 'ilk seçilen BİRİNCİL kalıyor');
      expect(get().extraTopicCount, 2);
    });

    test('aynı konuya ikinci dokunuş ÇIKARIYOR', () {
      pickSubject();
      n().toggleTopic(id: 't1', name: 'Türev');
      n().toggleTopic(id: 't2', name: 'İntegral');
      n().toggleTopic(id: 't1', name: 'Türev');

      expect(get().topicIds, ['t2']);
      expect(get().topicNames, ['İntegral']);
      expect(get().topicId, 't2', reason: 'birincil düşünce sıradaki geçiyor');
    });

    test('hepsini çıkarınca konusuz oturuma dönülüyor', () {
      pickSubject();
      n().toggleTopic(id: 't1', name: 'Türev');
      n().toggleTopic(id: 't1', name: 'Türev');

      expect(get().topicIds, isEmpty);
      expect(get().topicId, isNull);
    });

    test('selectTopic çoklu seçimi TEKE indiriyor', () {
      pickSubject();
      n().toggleTopic(id: 't1', name: 'Türev');
      n().toggleTopic(id: 't2', name: 'İntegral');
      n().selectTopic(id: 't3', name: 'Limit');

      expect(get().topicIds, ['t3']);
    });

    test('skipTopic listeyi temizliyor, ders ve tür duruyor', () {
      pickSubject();
      n().selectActivityType(id: 'act_soru', name: 'Soru Çözümü');
      n().toggleTopic(id: 't1', name: 'Türev');
      n().skipTopic();

      expect(get().topicIds, isEmpty);
      expect(get().subjectId, 'sub_yks_1');
      expect(get().activityTypeId, 'act_soru');
    });

    test('reset her şeyi siliyor', () {
      pickSubject();
      n().toggleTopic(id: 't1', name: 'Türev');
      n().reset();

      expect(get(), const SetupSelection());
    });
  });

  group('eşitlik DEĞERE göre', () {
    test('aynı içerikli iki liste EŞİT sayılıyor', () {
      // Dart'ta `List` `==` kimlik karşılaştırıyor; elle yazılmadan
      // Riverpod her `copyWith`te yeniden çizerdi.
      const a = SetupSelection(topicIds: ['t1', 't2']);
      const b = SetupSelection(topicIds: ['t1', 't2']);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('SIRA farkı eşitliği bozuyor — birincil konu değişiyor', () {
      const a = SetupSelection(topicIds: ['t1', 't2']);
      const b = SetupSelection(topicIds: ['t2', 't1']);
      expect(a, isNot(b));
    });

    test('uzunluk farkı eşitliği bozuyor', () {
      const a = SetupSelection(topicIds: ['t1']);
      const b = SetupSelection(topicIds: ['t1', 't2']);
      expect(a, isNot(b));
    });
  });

  test('plan ekranına geçmek için konu ZORUNLU DEĞİL', () {
    pickSubject();
    n().selectActivityType(id: 'act_soru', name: 'Soru Çözümü');
    expect(get().isReadyForPlan, isTrue);
  });
}
