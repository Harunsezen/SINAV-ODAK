// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

/// Kullanıcının bildirim tercihleri.
///
/// Ayar satırından okunur; `LocalSessionNotifier` bunlara **uymak
/// zorundadır**. FAZ 8 öncesinde bu üç ayar yalnızca Ayarlar ekranında
/// yazılıyor, bildirim katmanı hiç okumuyordu: kullanıcı bildirimleri
/// kapatsa bile kurulmaya devam ediyordu.
class NotificationPrefs {
  const NotificationPrefs({
    this.enabled = true,
    this.sound = true,
    this.vibration = true,
  });

  static const defaults = NotificationPrefs();

  /// Kapalıysa **hiçbir bildirim kurulmaz**.
  final bool enabled;
  final bool sound;
  final bool vibration;

  /// Android bildirim kanalı kimliği.
  ///
  /// **Neden ses/titreşim başına AYRI kanal:** Android'de bir kanal bir kez
  /// oluşturulduktan sonra ses ve titreşim ayarları **koddan
  /// değiştirilemez** — sistem kullanıcının kanal üzerindeki tercihini
  /// korur. Tek kanal kullanıp `playSound` değerini değiştirmek hiçbir işe
  /// yaramaz; ayar sessizce yok sayılırdı. Her kombinasyona ayrı kanal
  /// vermek, Android'in kanal modeliyle çalışan tek doğru yol.
  String get channelId => 'session_s${sound ? 1 : 0}_v${vibration ? 1 : 0}';

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.enabled == enabled &&
      other.sound == sound &&
      other.vibration == vibration;

  @override
  int get hashCode => Object.hash(enabled, sound, vibration);

  @override
  String toString() => 'NotificationPrefs(enabled: $enabled, sound: $sound, '
      'vibration: $vibration)';
}
