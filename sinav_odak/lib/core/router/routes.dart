/// Tüm route yolları tek yerde. Sihirli string kullanılmaz.
abstract final class Routes {
  static const home = '/home';
  static const stats = '/stats';
  static const wrongs = '/wrongs';

  /// Elle yanlış ekleme. Shell DIŞINDA açılır (form odaklı ekran).
  static const wrongsAdd = '/wrongs/add';
  static const calendar = '/calendar';
  static const settings = '/settings';

  // Oturum kurulum akışı (Adım 4'te doldurulacak)
  static const sessionSubject = '/session/subject';
  static const sessionTopic = '/session/topic';
  static const sessionType = '/session/type';
  static const sessionPlan = '/session/plan';

  // KİTAP OKUMA KATMANI (v1.3) — alt navigasyon GİZLİ
  //
  // Çalışma oturumundan AYRI bir yol ailesi: kitap oturumunun ders/konu/
  // tür adımları yok, sayacı farklı çalışıyor ve oturum sonu formu
  // doğru/yanlış sormuyor. `/run` altına konsaydı her ekran "bu hangi
  // oturum" diye dallanmak zorunda kalırdı.
  static const book = '/book';
  static const bookRun = '/book/run';
  static const bookSummary = '/book/summary';

  // Aktif oturum katmanı — alt navigasyon GİZLİ
  static const run = '/run';
  static const runBreak = '/run/break';
  static const runSummary = '/run/summary';
  static const runDone = '/run/done';

  static const onboarding = '/onboarding';
  static const manage = '/manage';

  /// Müfredat ağacı (Ayarlar > Müfredat). Shell DIŞINDA: gezinme
  /// çubuğu, arama kutusu açıkken klavyeyle yer paylaşıyordu.
  static const curriculum = '/curriculum';
  static const goals = '/goals';
  static const achievements = '/achievements';
}
