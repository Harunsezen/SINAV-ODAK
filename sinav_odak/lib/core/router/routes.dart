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

  // Aktif oturum katmanı — alt navigasyon GİZLİ
  static const run = '/run';
  static const runBreak = '/run/break';
  static const runSummary = '/run/summary';
  static const runDone = '/run/done';

  static const onboarding = '/onboarding';
  static const manage = '/manage';
  static const goals = '/goals';
  static const achievements = '/achievements';
}
