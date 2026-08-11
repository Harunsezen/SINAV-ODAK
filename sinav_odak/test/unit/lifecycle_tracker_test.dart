import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/services/background/lifecycle_tracker.dart';

import 'usecase_helpers.dart';

void main() {
  // WidgetsBinding.instance.addObserver çağrısı için gerekli.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int fakeNow;
  late LifecycleTracker tracker;

  /// Zaman dışarıdan verilir; DateTime.now() KULLANILMAZ.
  setUp(() async {
    db = newDb();
    fakeNow = t0;
    tracker = LifecycleTracker(db, nowMsProvider: () => fakeNow);
    await seedRunningSession(db, id: 's1', sch: schedule());
  });

  tearDown(() async {
    await tracker.detach();
    await db.close();
  });

  Future<StudySession> read() async => (await db.sessionDao.findById('s1'))!;

  void advance(int seconds) => fakeNow += seconds * 1000;

  test('başlangıçta sayaçlar sıfır', () async {
    final s = await read();
    expect(s.awayS, 0);
    expect(s.exitCount, 0);
    expect(s.foregroundS, 0);
  });

  test('paused + resumed -> awayS ve exitCount artıyor', () async {
    tracker.attach('s1');

    tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
    advance(90);
    tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    final s = await read();
    expect(s.awayS, 90);
    expect(s.exitCount, 1);
  });

  test('birden fazla çıkış toplanıyor', () async {
    tracker.attach('s1');

    for (final away in [30, 60, 10]) {
      tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
      advance(away);
      tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
    }

    final s = await read();
    expect(s.awayS, 100);
    expect(s.exitCount, 3);
  });

  test('inactive ÇIKIŞ SAYILMIYOR', () async {
    tracker.attach('s1');

    // Bildirim paneli açıldı, kapandı.
    tracker.didChangeAppLifecycleState(AppLifecycleState.inactive);
    advance(45);
    tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    final s = await read();
    expect(s.awayS, 0, reason: 'inactive dışarıda geçmiş sayılmaz');
    expect(s.exitCount, 0);
  });

  test('art arda paused tek çıkış sayılıyor', () async {
    tracker.attach('s1');

    tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
    advance(20);
    tracker.didChangeAppLifecycleState(AppLifecycleState.hidden);
    advance(20);
    tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    final s = await read();
    expect(s.awayS, 40, reason: 'ilk çıkış anından itibaren');
    expect(s.exitCount, 1);
  });

  test('dışarıdayken detach: son dilim yazılıyor, çıkış sayılmıyor', () async {
    tracker.attach('s1');

    tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
    advance(120);
    await tracker.detach();

    final s = await read();
    expect(s.awayS, 120);
    expect(s.exitCount, 0, reason: 'kullanıcı geri dönmedi, çıkış sayılmaz');
  });

  test('detach sonrası lifecycle olayları yok sayılıyor', () async {
    tracker.attach('s1');
    await tracker.detach();

    tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
    advance(300);
    tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    final s = await read();
    expect(s.awayS, 0);
    expect(s.exitCount, 0);
  });

  test('attach edilmeden olay gelirse hiçbir şey yazılmıyor', () async {
    tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
    advance(60);
    tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    final s = await read();
    expect(s.awayS, 0);
  });

  test('iki kez attach ikinci oturumu izlemiyor', () async {
    tracker.attach('s1');
    tracker.attach('baska-oturum');
    expect(tracker.trackedSessionId, 's1');
  });

  test('isAway durumu doğru raporlanıyor', () async {
    tracker.attach('s1');
    expect(tracker.isAway, isFalse);

    tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(tracker.isAway, isTrue);

    tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(tracker.isAway, isFalse);
  });
}
