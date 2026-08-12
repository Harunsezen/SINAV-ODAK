import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/theme/app_theme.dart';

/// `AppTheme`'in buton kısıtları — **tuzağın bekçisi.**
///
/// `filledButtonTheme` tüm `FilledButton`'lara
/// `minimumSize: Size.fromHeight(56)` veriyor; bu `Size(double.infinity, 56)`
/// demek. `Column` içinde genişlik sınırlı olduğundan istenen "tam genişlik"
/// görünümünü üretiyor. Ama genişliği **sınırsız** veren bir kapsayıcının
/// (en sık `Row`) içinde sonsuz asgari genişlik geçerli olmayan bir kısıta
/// dönüşüyor, buton yerleşemiyor ve çizilmiyor.
///
/// Onboarding alt barı bu yüzden cihazda bozuktu (ONBOARDING_BUG.md).
/// Bu dosya hem davranışı belgeliyor hem de düzeltmenin geri alınmasını
/// yakalıyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets(
      'tema, Column içindeki FilledButton\'ı tam genişlik yapıyor '
      '(kasıtlı davranış)', (tester) async {
    await pump(
      tester,
      const SizedBox(
        width: 300,
        child: Column(
          children: [
            FilledButton(
              key: Key('sut'),
              onPressed: null,
              child: Text('Tam genişlik'),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final r = tester.getRect(find.byKey(const Key('sut')));
    expect(r.width, 300, reason: 'Column içinde tam genişlik beklenir');
    expect(r.height, 56, reason: 'tema yüksekliği 56');
  });

  testWidgets(
      'DOĞRULANMIŞ TUZAK: sade FilledButton bir Row içinde sonsuz '
      'genişlik kısıtı üretiyor', (tester) async {
    // Kısıt hatası her yerleşim geçişinde yeniden atılıyor; `takeException`
    // o durumda tek tek hataları değil "Multiple exceptions" özetini
    // veriyor. İlk hatanın METNİNİ görebilmek için hata kancasını geçici
    // olarak kendimiz alıyoruz.
    final caught = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError =
        (details) => caught.add(details.exception.toString());

    await pump(
      tester,
      const Row(
        children: [
          Spacer(),
          FilledButton(
            key: Key('sut'),
            onPressed: null,
            child: Text('İleri'),
          ),
        ],
      ),
    );

    FlutterError.onError = previous;

    // Bu testin AMACI hatayı üretmek: tuzak gerçek olmasa düzeltme de
    // gereksiz olurdu. Hata mesajı değişirse burası bizi uyarır.
    expect(
      caught,
      isNotEmpty,
      reason: 'tuzak kapanmışsa (Flutter/tema değişmişse) '
          'onboarding_screen.dart\'taki yerel stil de gözden geçirilmeli',
    );
    expect(
      caught.first,
      contains('infinite width'),
      reason: 'beklenen hata "BoxConstraints forces an infinite width"',
    );
  });

  testWidgets(
      'ÇÖZÜM: yerel minimumSize verilince Row içinde sorunsuz '
      'yerleşiyor', (tester) async {
    await pump(
      tester,
      Row(
        children: [
          const Spacer(),
          FilledButton(
            key: const Key('sut'),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 56)),
            onPressed: null,
            child: const Text('İleri'),
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    final r = tester.getRect(find.byKey(const Key('sut')));
    expect(r.width, greaterThanOrEqualTo(88));
    expect(r.width, lessThan(800), reason: 'sonsuz genişlik kalmadı');
    expect(r.height, 56, reason: 'tema yüksekliği korunuyor');
  });

  testWidgets('ÇÖZÜM 2: Expanded ile sınırlamak da çalışıyor', (tester) async {
    await pump(
      tester,
      const Row(
        children: [
          Spacer(),
          Expanded(
            child: FilledButton(
              key: Key('sut'),
              onPressed: null,
              child: Text('İleri'),
            ),
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byKey(const Key('sut'))).height, 56);
  });
}
