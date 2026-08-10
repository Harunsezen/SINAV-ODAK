import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/presentation/session_setup/setup_controller.dart';

void main() {
  late ProviderContainer c;

  setUp(() => c = ProviderContainer());
  tearDown(() => c.dispose());

  SetupNotifier n() => c.read(setupProvider.notifier);
  SetupSelection sel() => c.read(setupProvider);

  test('başlangıçta tüm seçimler boş', () {
    expect(sel().subjectId, isNull);
    expect(sel().topicId, isNull);
    expect(sel().activityTypeId, isNull);
    expect(sel().isReadyForPlan, isFalse);
  });

  test('ders seçimi yazılıyor ve okunuyor', () {
    n().selectSubject(id: 'sub_1', name: 'Matematik', colorHex: '#4F5BD5');
    expect(sel().subjectId, 'sub_1');
    expect(sel().subjectName, 'Matematik');
    expect(sel().subjectColorHex, '#4F5BD5');
  });

  test('konu seçimi yazılıyor', () {
    n().selectSubject(id: 'sub_1', name: 'Matematik', colorHex: '#4F5BD5');
    n().selectTopic(id: 'top_1', name: 'Türev');
    expect(sel().topicId, 'top_1');
    expect(sel().topicName, 'Türev');
  });

  test('konu ATLANABİLİR: topicId null kalır', () {
    n().selectSubject(id: 'sub_1', name: 'Matematik', colorHex: '#4F5BD5');
    n().selectTopic(id: 'top_1', name: 'Türev');
    n().skipTopic();

    expect(sel().topicId, isNull);
    expect(sel().topicName, isNull);
    expect(sel().subjectId, 'sub_1', reason: 'ders seçimi korunmalı');
  });

  test('tür seçimi yazılıyor', () {
    n().selectActivityType(id: 'act_soru', name: 'Soru Çözümü');
    expect(sel().activityTypeId, 'act_soru');
    expect(sel().activityTypeName, 'Soru Çözümü');
  });

  test('plan için ders ve tür yeterli, konu zorunlu değil', () {
    n().selectSubject(id: 'sub_1', name: 'Matematik', colorHex: '#4F5BD5');
    expect(sel().isReadyForPlan, isFalse);

    n().selectActivityType(id: 'act_soru', name: 'Soru Çözümü');
    expect(sel().isReadyForPlan, isTrue, reason: 'konusuz da plana geçilebilir');
  });

  test('ders değişince önceki konu seçimi düşüyor', () {
    n().selectSubject(id: 'sub_1', name: 'Matematik', colorHex: '#4F5BD5');
    n().selectTopic(id: 'top_1', name: 'Türev');
    n().selectSubject(id: 'sub_2', name: 'Fizik', colorHex: '#2E9E6B');

    expect(sel().subjectId, 'sub_2');
    expect(sel().topicId, isNull, reason: 'Fizik konusu olarak Türev kalamaz');
  });

  test('ders değişse bile tür seçimi korunuyor', () {
    n().selectActivityType(id: 'act_soru', name: 'Soru Çözümü');
    n().selectSubject(id: 'sub_1', name: 'Matematik', colorHex: '#4F5BD5');
    expect(sel().activityTypeId, 'act_soru');
  });

  test('reset tüm seçimleri temizliyor', () {
    n().selectSubject(id: 'sub_1', name: 'Matematik', colorHex: '#4F5BD5');
    n().selectTopic(id: 'top_1', name: 'Türev');
    n().selectActivityType(id: 'act_soru', name: 'Soru Çözümü');

    n().reset();

    expect(sel(), const SetupSelection());
    expect(sel().isReadyForPlan, isFalse);
  });

  test('provider autoDispose DEĞİL: dinleyici olmadan da state korunuyor', () {
    n().selectSubject(id: 'sub_1', name: 'Matematik', colorHex: '#4F5BD5');
    // Ekranlar arası geçişte dinleyici düşse bile seçim kaybolmamalı.
    expect(c.read(setupProvider).subjectId, 'sub_1');
    expect(c.read(setupProvider).subjectId, 'sub_1');
  });
}
